#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

cd "$(dirname "${BASH_SOURCE[0]}")"

# create the action image.
docker build -t $TINKERBELL_HOST_IP/reboot .
docker push $TINKERBELL_HOST_IP/reboot
