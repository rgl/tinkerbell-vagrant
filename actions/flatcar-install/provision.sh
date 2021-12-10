#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh
cd "$(dirname "${BASH_SOURCE[0]}")"

# build the action image.
docker buildx build \
    --tag $TINKERBELL_HOST_IP/flatcar-install \
    --output type=registry \
    --platform linux/amd64,linux/arm64 \
    --progress plain \
    .
docker manifest inspect $TINKERBELL_HOST_IP/flatcar-install
