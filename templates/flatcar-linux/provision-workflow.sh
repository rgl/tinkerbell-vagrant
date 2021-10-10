#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh
cd "$(dirname "${BASH_SOURCE[0]}")"

hardware_hostname="$1"
boot_device="${2:-/dev/sda}"
provisioner_ip_address="$TINKERBELL_HOST_IP"

# install the flatcar linux configuration to ignition file transpiler.
if [ ! -f tmp/ct ]; then
  mkdir -p tmp
	wget -qO tmp/ct.tmp https://github.com/coreos/container-linux-config-transpiler/releases/download/v0.9.0/ct-v0.9.0-x86_64-unknown-linux-gnu
	chmod +x tmp/ct.tmp
  mv tmp/ct{.tmp,}
fi

# find the hardware with the given hostname.
hardware_mac="$(get-hardware-mac "$hardware_hostname")"

# find the template id.
template_id="$(tink template get --format json | jq -r '.data[] | select(.name=="flatcar-linux") | .id')"

# delete the workflows associated with the hardware.
delete-hardware-workflows "$hardware_hostname"

# create the workflow associated with the hardware.
ignition="$(cat flatcar-linux-config.yml | CORE_SSH_PUBLIC_KEY="$(cat /vagrant/tmp/id_rsa.pub)" DOLLAR='$' envsubst | ./tmp/ct | base64 -w0)"
hardware="$(jo device_1="$hardware_mac" ignition="$ignition" boot_device="$boot_device")"
workflow_output="$(tink workflow create --template "$template_id" --hardware "$hardware")"
workflow_id="$(echo "$workflow_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
tink workflow get "$workflow_id"
