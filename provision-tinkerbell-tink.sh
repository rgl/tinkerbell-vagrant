#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

# checkout the tinkerbell tink repository.
if [ ! -d ~/tinkerbell-tink ]; then
    cd ~
    git clone --no-checkout https://github.com/tinkerbell/tink.git tinkerbell-tink
    cd tinkerbell-tink
    git checkout -f 187a3c7b37caf17be5c17a612da752778b2940f7 # 2021-11-02T19:01:59Z
fi

# build tink-worker.
# see https://github.com/tinkerbell/tink/pull/549
# see https://github.com/tinkerbell/tink/pull/552
cd ~/tinkerbell-tink
go install golang.org/x/tools/cmd/goimports
go install golang.org/x/tools/cmd/stringer
rm -rf bin
ln -sf "$(go env GOPATH)/bin" bin
make cmd/tink-worker/tink-worker-linux-amd64 cmd/tink-worker/tink-worker-linux-arm64
docker buildx build \
    --tag $TINKERBELL_HOST_IP/tink-worker \
    --output type=registry \
    --platform linux/amd64,linux/arm64 \
    --progress plain \
    cmd/tink-worker
docker manifest inspect $TINKERBELL_HOST_IP/tink-worker

# ensure tink-worker will not be re-installed by compose.
sed -i -E 's,^([^#]+ tink-worker:latest),#\1,g' ~/tinkerbell-sandbox/deploy/compose/registry/registry_images.txt
