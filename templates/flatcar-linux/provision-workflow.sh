#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh
cd "$(dirname "${BASH_SOURCE[0]}")"

hardware_hostname="$1"
boot_device="${2:-/dev/sda}"
provisioner_ip_address="$TINKERBELL_HOST_IP"

# find the hardware with the given hostname.
hardware_mac="$(tink hardware get | tr -d ' ' | awk -F '|' "/\|$hardware_hostname\|\$/{print \$3}")"

# find the template id.
template_id="$(tink template get --format json | jq -r '.data[] | select(.name=="flatcar-linux") | .id')"

# delete the workflows associated with the hardware.
delete-hardware-workflows "$hardware_hostname"

# create the workflow associated with the hardware.
ignition="$(cat flatcar-linux-config.yml | CORE_SSH_PUBLIC_KEY="$(cat /vagrant/tmp/id_rsa.pub)" DOLLAR='$' envsubst | ./tmp/ct | base64 -w0)"
hardware="$(jo device_1=$hardware_mac ignition=$ignition boot_device=$boot_device)"
workflow_output="$(tink workflow create --template "$template_id" --hardware "$hardware")"
workflow_id="$(echo "$workflow_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
tink workflow get "$workflow_id"
