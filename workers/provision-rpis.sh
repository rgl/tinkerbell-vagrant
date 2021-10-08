#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

cd "$(dirname "${BASH_SOURCE[0]}")"

export provisioner_ip_address="$TINKERBELL_HOST_IP"
worker_ip_address_prefix="$(echo $provisioner_ip_address | cut -d "." -f 1).$(echo $provisioner_ip_address | cut -d "." -f 2).$(echo $provisioner_ip_address | cut -d "." -f 3)"

# provision the rpi physical machine workers hardware and respective workflow.
# see https://tinkerbell.org/hardware-data/
# see Hardware type at https://github.com/tinkerbell/boots/blob/9b8953aca0dc54be52f49a2062b0b2dbc6356283/packet/models.go#L54-L75
# see DiscoveryTinkerbellV1 type at https://github.com/tinkerbell/boots/blob/9b8953aca0dc54be52f49a2062b0b2dbc6356283/packet/models_tinkerbell.go#L16-L20
# see HardwareTinkerbellV1 type at https://github.com/tinkerbell/boots/blob/9b8953aca0dc54be52f49a2062b0b2dbc6356283/packet/models_tinkerbell.go#L22-L27
# see Arch at https://github.com/tinkerbell/boots/blob/9b8953aca0dc54be52f49a2062b0b2dbc6356283/dhcp/pxe.go#L61-L71
workers=(
  "dc:a6:32:27:e0:37 $worker_ip_address_prefix.101 rpi1"
  "dc:a6:32:27:f7:cb $worker_ip_address_prefix.102 rpi2"
  "dc:a6:32:27:f7:fb $worker_ip_address_prefix.103 rpi3"
  "dc:a6:32:27:f7:89 $worker_ip_address_prefix.104 rpi4"
  "dc:a6:32:27:f5:46 $worker_ip_address_prefix.123 rpijoy"
  "dc:a6:32:b0:ba:1d $worker_ip_address_prefix.124 rpi8gb"
)
for worker in "${workers[@]}"; do
  worker_mac_address="$(echo "$worker" | awk '{print $1}')"
  worker_ip_address="$(echo "$worker" | awk '{print $2}')"
  worker_name="$(echo "$worker" | awk '{print $3}')"
  worker_id="00000000-0000-4000-8000-$(echo -n "$worker_mac_address" | tr -d :)"

  # create the hardware.
  tink hardware push <<EOF
{
  "id": "$worker_id",
  "metadata": {
    "facility": {
      "facility_code": "onprem"
    },
    "instance": {},
    "state": ""
  },
  "network": {
    "interfaces": [
      {
        "dhcp": {
          "arch": "aarch64",
          "uefi": true,
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
