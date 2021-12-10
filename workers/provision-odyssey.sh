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
# NB remotely manage this with meshcommander that is running at the provisioner port 4000 and connect to this machine AMT at http://10.3.0.14:16992.
workers=(
  # Seeed Studio Odyssey X86J4105 board https://wiki.seeedstudio.com/ODYSSEY-X86J4105/
  # see https://github.com/rgl/seeedstudio-odyssey-x86j4105-notes
  "00:e0:4c:01:93:a8 $worker_ip_address_prefix.15 odyssey"
)
for worker in "${workers[@]}"; do
  export worker_mac_address="$(echo "$worker" | awk '{print $1}')"
  export worker_ip_address="$(echo "$worker" | awk '{print $2}')"
  export worker_name="$(echo "$worker" | awk '{print $3}')"
  export worker_id="00000000-0000-4000-8000-$(echo -n "$worker_mac_address" | tr -d :)"

  # create the hardware.
  cat hardware-odyssey.json | DOLLAR='$' envsubst | tink hardware push

  # show the hardware.
  tink hardware mac "$worker_mac_address"

  # create the workflow.
  bash ../templates/hello-world/provision-workflow.sh "$worker_name"
done
