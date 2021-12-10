#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

# checkout the tinkerbell tink repository.
if [ ! -d ~/tinkerbell-tink ]; then
    cd ~
    git clone --no-checkout https://github.com/tinkerbell/tink.git tinkerbell-tink
    cd tinkerbell-tink
    git checkout -f b72ab0bd24a47ef3c42d682f9ab80e3825655a82 # 2021-12-03T22:35:03Z
fi

# build tink-worker.
# see https://github.com/tinkerbell/tink/pull/549 tink-worker: do not attach the action container stdout/stderr to the current process when --capture-action-logs=false
# see https://github.com/tinkerbell/tink/pull/552 Upgrade to PostgreSQL 14
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
sed -i -E 's,^(quay\.io/tinkerbell/tink-worker:.+),#\1,g' ~/tinkerbell-sandbox/deploy/compose/registry/registry_images.txt
