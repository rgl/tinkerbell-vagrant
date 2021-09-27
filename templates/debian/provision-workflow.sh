#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

cd "$(dirname "${BASH_SOURCE[0]}")"

hardware_hostname="$1"
boot_device="${2:-/dev/sda}"
img_url="http://$TINKERBELL_HOST_IP:8080/images/debian-amd64/"
img_url="nfs://$TINKERBELL_HOST_IP/var/nfs/images/debian-amd64"

# create the image.
# NB this image can created from https://github.com/rgl/debian-vagrant.
install-vagrant-box-clonezilla-image debian-11-uefi-amd64 debian-amd64

# find the hardware with the given hostname.
hardware_mac="$(tink hardware get --format json | jq -r --arg hostname "$hardware_hostname" '.data[].network.interfaces[] | select(.dhcp.hostname==$hostname) | .dhcp.mac')"

# find the template id.
template_id="$(tink template get --format json | jq -r '.data[] | select(.name=="debian") | .id')"

# delete the workflows associated with the hardware.
delete-hardware-workflows "$hardware_hostname"

# create the workflow associated with the hardware.
hardware="$(jo device_1="$hardware_mac" img_url="$img_url" boot_device="$boot_device")"
workflow_output="$(tink workflow create --template "$template_id" --hardware "$hardware")"
workflow_id="$(echo "$workflow_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
tink workflow get "$workflow_id"
