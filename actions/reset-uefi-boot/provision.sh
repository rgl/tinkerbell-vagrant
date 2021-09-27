#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

cd "$(dirname "${BASH_SOURCE[0]}")"

# create the action image.
docker build -t $TINKERBELL_HOST_IP/reset-uefi-boot .
docker push $TINKERBELL_HOST_IP/reset-uefi-boot
