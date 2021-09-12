#!/bin/bash
set -euxo pipefail
source /root/tink-helpers.source.sh

cd "$(dirname "${BASH_SOURCE[0]}")"

export provisioner_ip_address="$TINKERBELL_HOST_IP"
worker_ip_address_prefix="$(echo $provisioner_ip_address | cut -d "." -f 1).$(echo $provisioner_ip_address | cut -d "." -f 2).$(echo $provisioner_ip_address | cut -d "." -f 3)"

# install the flatcar linux configuration to ignition file transpiler.
if [ ! -f tmp/ct ]; then
  mkdir -p tmp
	wget -qO tmp/ct.tmp https://github.com/coreos/container-linux-config-transpiler/releases/download/v0.9.0/ct-v0.9.0-x86_64-unknown-linux-gnu
	chmod +x tmp/ct.tmp
  mv tmp/ct{.tmp,}
fi

# create the action images.
docker build -t $TINKERBELL_HOST_IP/flatcar-install -f Dockerfile.flatcar-install .
docker push $TINKERBELL_HOST_IP/flatcar-install
docker build -t $TINKERBELL_HOST_IP/reboot -f Dockerfile.reboot .
docker push $TINKERBELL_HOST_IP/reboot

# create the template.
delete-template flatcar-linux
template_output="$(cat workflow-template.yml | tink template create)"
template_id="$(echo "$template_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
tink template get "$template_id"
