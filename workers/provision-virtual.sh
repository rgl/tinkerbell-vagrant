#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

cd "$(dirname "${BASH_SOURCE[0]}")"

export provisioner_ip_address="$TINKERBELL_HOST_IP"
worker_ip_address_prefix="$(echo $provisioner_ip_address | cut -d "." -f 1).$(echo $provisioner_ip_address | cut -d "." -f 2).$(echo $provisioner_ip_address | cut -d "." -f 3)"

# create the hardware information about our workers.
# see https://docs.tinkerbell.org/hardware-data/
# see Hardware type at https://github.com/tinkerbell/boots/blob/9b8953aca0dc54be52f49a2062b0b2dbc6356283/packet/models.go#L54-L75
# see DiscoveryTinkerbellV1 type at https://github.com/tinkerbell/boots/blob/9b8953aca0dc54be52f49a2062b0b2dbc6356283/packet/models_tinkerbell.go#L16-L20
# see HardwareTinkerbellV1 type at https://github.com/tinkerbell/boots/blob/9b8953aca0dc54be52f49a2062b0b2dbc6356283/packet/models_tinkerbell.go#L22-L27
# see Arch at https://github.com/tinkerbell/boots/blob/9b8953aca0dc54be52f49a2062b0b2dbc6356283/dhcp/pxe.go#L61-L71
workers=(
  "08:00:27:00:00:01 $worker_ip_address_prefix.11 bios false" # the bios_worker vm.
  "08:00:27:00:00:02 $worker_ip_address_prefix.12 uefi true"  # the uefi_worker vm.
)
for worker in "${workers[@]}"; do
  worker_mac_address="$(echo "$worker" | awk '{print $1}')"
  worker_ip_address="$(echo "$worker" | awk '{print $2}')"
  worker_name="$(echo "$worker" | awk '{print $3}')"
  worker_efi_boot="$(echo "$worker" | awk '{print $4}')"
  worker_id="00000000-0000-4000-8000-$(echo -n "$worker_mac_address" | tr -d :)"

  # create the hardware.
  tink hardware push <<EOF
{
  "id": "$worker_id",
  "metadata": {
    "facility": {
      "facility_code": "onprem"
    },
    "instance": {
      "hostname": "$worker_name"
    },
    "state": ""
  },
  "network": {
    "interfaces": [
      {
        "dhcp": {
          "arch": "x86_64",
          "uefi": $worker_efi_boot,
          "mac": "$worker_mac_address",
          "ip": {
            "address": "$worker_ip_address",
            "netmask": "255.255.255.0",
            "gateway": "$provisioner_ip_address"
          },
          "lease_time": 86400,
          "name_servers": ["1.1.1.1", "1.0.0.1"],
          "hostname": "$worker_name",
          "iface_name": "eth0"
        },
        "netboot": {
          "allow_pxe": true,
          "allow_workflow": true
        }
      }
    ]
  }
}
EOF

  # show the hardware.
  tink hardware mac "$worker_mac_address"

  # create the workflow.
  bash ../templates/hello-world/provision-workflow.sh "$worker_name"
done
