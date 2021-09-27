#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh
cd "$(dirname "${BASH_SOURCE[0]}")"

# build the action image.
docker build -t $TINKERBELL_HOST_IP/flatcar-install .
docker push $TINKERBELL_HOST_IP/flatcar-install
