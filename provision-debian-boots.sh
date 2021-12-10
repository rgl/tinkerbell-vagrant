#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

# checkout the tinkerbell boots repository.
if [ ! -d ~/tinkerbell-boots ]; then
    cd ~
    git clone --no-checkout https://github.com/rgl/tinkerbell-boots.git tinkerbell-boots
    cd tinkerbell-boots
    git checkout -f rgl-debian-osie
fi

# install dependencies.
apt-get install -y gcc-aarch64-linux-gnu build-essential liblzma-dev

# build.
cd ~/tinkerbell-boots
go install golang.org/x/tools/cmd/goimports
go install golang.org/x/tools/cmd/stringer
go install github.com/golang/mock/mockgen
rm -rf bin
ln -sf "$(go env GOPATH)/bin" bin
if [ ! -f ipxe/ipxe/ipxe.efi ]; then # do not rebuild when its already there.
    if [ ! -d /vagrant/tmp/ipxe ]; then # do not rebuild when its cached in the host.
        make ipxe
        rm -rf /vagrant/tmp/ipxe
        mkdir -p /vagrant/tmp/ipxe
        cp ipxe/ipxe/*.{efi,kpxe} /vagrant/tmp/ipxe
    else
        cp /vagrant/tmp/ipxe/*.{efi,kpxe} ipxe/ipxe/
    fi
fi
sed -i -E 's,^(cmd/boots/boots: .+) ipxe (.+),\1 \2,g' rules.mk # remove the ipxe dep (we've built or copied it over in the previous step and do not want to build it again).
make cmd/boots/boots-linux-amd64 cmd/boots/boots-linux-arm64
docker buildx build \
    --tag $TINKERBELL_HOST_IP/debian-boots \
    --output type=registry \
    --platform linux/amd64,linux/arm64 \
    --progress plain \
    .
docker manifest inspect $TINKERBELL_HOST_IP/debian-boots

# install and restart tinkerbell.
cd ~/tinkerbell-sandbox/deploy/compose
sed -i -E "s,(BOOTS_SERVER_IMAGE)=.*,\\1=$TINKERBELL_HOST_IP/debian-boots,g" .env
source .env
docker compose rm --stop --force boots
docker rmi --force $TINKERBELL_HOST_IP/debian-boots
docker compose up --quiet-pull --detach
