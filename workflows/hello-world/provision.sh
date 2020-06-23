#!/bin/bash
set -euxo pipefail

source /root/tink/envrc

export provisioner_ip_address="$TINKERBELL_HOST_IP"
worker_ip_address_prefix="$(echo $provisioner_ip_address | cut -d "." -f 1).$(echo $provisioner_ip_address | cut -d "." -f 2).$(echo $provisioner_ip_address | cut -d "." -f 3)"

# provision the example hello-world x86_64 image.
docker pull hello-world
docker tag hello-world $provisioner_ip_address/hello-world:x86_64-latest
docker push $provisioner_ip_address/hello-world:x86_64-latest

# provision the example hello-world arm32v7 image.
docker pull arm32v7/hello-world:linux
docker tag arm32v7/hello-world:linux $provisioner_ip_address/hello-world:arm32v7-latest
docker push $provisioner_ip_address/hello-world:arm32v7-latest

# provision the example hello-world workflow template.
# see https://tinkerbell.org/examples/hello-world/
template_output="$(docker exec -i deploy_tink-cli_1 tink template create --name hello-world <<EOF
version: '0.1'
global_timeout: 600
tasks:
  - name: hello-world
    worker: {{.device_1}}
    actions:
      - name: hello-world
        image: hello-world:{{.arch}}-latest
        timeout: 60
EOF
)"
template_id="$(echo "$template_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
docker exec -i deploy_tink-cli_1 tink template get "$template_id"

# provision the x86_64 machines workers hardware and respective workflow.
# see https://tinkerbell.org/hardware-data/
# see type HardwareTinkerbellV1 at https://github.com/tinkerbell/boots/blob/b88dc4e644701b5a946e5e6dee5888b2503294f7/packet/models.go#L101-L106
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
  docker exec -i deploy_tink-cli_1 tink hardware push <<EOF
{
  "id": "$worker_id",
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
          "hostname": "$worker_name",
          "iface_name": "eth0"
        },
        "netboot": {
          "allow_pxe": true,
          "allow_workflow": true
        }
      }
    ]
  },
  "metadata": {
    "facility": {
      "facility_code": "onprem"
    },
    "instance": {},
    "state": "provisioning"
  }
}
EOF
  docker exec -i deploy_tink-cli_1 tink hardware mac "$worker_mac_address" | jq .
  # create the workflow.
  workflow_output="$(docker exec -i deploy_tink-cli_1 tink workflow create --template "$template_id" --hardware "{\"device_1\": \"$worker_mac_address\", \"arch\": \"x86_64\"}")"
  workflow_id="$(echo "$workflow_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
  docker exec -i deploy_tink-cli_1 tink workflow get "$workflow_id"
done

# do not provisiong rpi has its currently broken.
exit 0

# replace the osie kernel and initrd with one what works with rpi4.
# NB the custom kernel and initrd was manually built by Adam Otto.
#    NB the kernel was built from https://github.com/raspberrypi/linux/tree/rpi-5.7.y with ARCH=arm64 bcm2711_defconfig.
#    NB the initrd was manually created and has no source.
# see https://github.com/ContainerSolutions/tinkerbell-rpi4-workflow/tree/rpi4-tinkerbell-uefi
wget \
  -qO /root/tink/deploy/state/webroot/misc/osie/current/vmlinuz-aarch64 \
  https://storage.googleapis.com/rpi4-uefi-tinkerbell/vmlinuz-aarch64
wget \
  -qO /root/tink/deploy/state/webroot/misc/osie/current/initramfs-aarch64 \
  https://storage.googleapis.com/rpi4-uefi-tinkerbell/initramfs-aarch64

# install a version of the tink-worker image that is compatible with the rpi4.
# NB the logs are stored at /tmp (e.g. /tmp/workflow.log).
docker pull ottovsky/tink-worker:armv7-latest
docker tag ottovsky/tink-worker:armv7-latest $provisioner_ip_address/tink-worker:armv7
docker push $provisioner_ip_address/tink-worker:armv7

# install a version of the fluent-bit image that is compatible with the rpi4.
docker pull fluent/fluent-bit:arm32v7-1.3.11
docker tag fluent/fluent-bit:arm32v7-1.3.11 $provisioner_ip_address/fluent-bit:1.3-arm
docker push $provisioner_ip_address/fluent-bit:1.3-arm

# provision the rpi physical machine workers hardware and respective workflow.
# see https://tinkerbell.org/hardware-data/
# see type Hardware at https://github.com/tinkerbell/boots/blob/98462c3397dd28f39572ecad01571ebf0e03974e/packet/models.go#L234
rpis=(
  "dc:a6:32:27:e0:37 $worker_ip_address_prefix.101 rpi1"
  "dc:a6:32:27:f7:cb $worker_ip_address_prefix.102 rpi2"
  "dc:a6:32:27:f7:fb $worker_ip_address_prefix.103 rpi3"
  "dc:a6:32:27:f7:89 $worker_ip_address_prefix.104 rpi4"
  "dc:a6:32:27:f5:46 $worker_ip_address_prefix.123 rpijoy"
)
for rpi in "${rpis[@]}"; do
  worker_mac_address="$(echo "$rpi" | awk '{print $1}')"
  worker_ip_address="$(echo "$rpi" | awk '{print $2}')"
  worker_name="$(echo "$rpi" | awk '{print $3}')"
  worker_id="00000000-0000-4000-8000-$(echo -n "$worker_mac_address" | tr -d :)"
  # create the hardware.
  # NB tinkerbell boots assumes that an arm machine will always uses UEFI when
  #    its PXE booting. it will always send the snp-nolacp.efi file as the boot
  #    filename.
  # NB the native rpi pxe client sends the DHCP Option (93) Client System
  #    Architecture as the incorrect IA x86 PC (0); because of that, tinkerbell
  #    boots, logs a mismatch warning about dhcp using x86_64 but the job using
  #    aarch64.
  # NB unfortunately there is no straightforward way to detect the rpi pxe
  #    client besides whitelisting the MAC vendor OR adding a property to the
  #    tinkerbell boots hardware json.
  #    see https://github.com/tinkerbell/boots/issues/23.
  # NB in conclusion, pxe is disabled and the pi must use an iPXE/UEFI sd-card.
  # NB tinkerbell boots will set the DHCP next server to 10.10.10.2 (our boots
  #    IP address) and filename to snp-nolacp.efi.
  # NB here we are abusing the facility_code variable to inject our custom
  #    kernel/initrd until osie properly supports the pie.
  # NB by default osie is launched with the follow ipxe script (for making
  #    things easier to read each option was put in different line):
  #     kernel
  #       ${base-url}/vmlinuz-${parch}
  #       ip=dhcp
  #       modules=loop,squashfs,sd-mod,usb-storage
  #       alpine_repo=${base-url}/repo-${arch}/main
  #       modloop=${base-url}/modloop-${parch}
  #       tinkerbell=${tinkerbell}
  #       parch=${parch}
  #       packet_action=${action}
  #       packet_state=${state}
  #       docker_registry=10.10.10.2
  #       grpc_authority=10.10.10.2:42113
  #       grpc_cert_url=http://10.10.10.2:42114/cert
  #       registry_username=tinkerbell
  #       registry_password=ebbe21b40ac61742f10fec4daed982e4f3658cd5ae89778632f9af23462ff9ea
  #       elastic_search_url=10.10.10.2:9200
  #       packet_base_url=http://10.10.10.3/workflow
  #       worker_id=00000000-0000-4000-8000-dca63227f546
  #       packet_bootdev_mac=${bootdevmac}
  #       facility=onprem
  #       plan=
  #       manufacturer=
  #       slug=
  #       initrd=initramfs-${parch}
  #       console=ttyAMA0,115200
  #     initrd ${base-url}/initramfs-${parch}
  docker exec -i deploy_tink-cli_1 tink hardware push <<EOF
{
  "id": "$worker_id",
  "name": "$worker_name",
  "arch": "aarch64",
  "efi_boot": true,
  "allow_pxe": false,
  "allow_workflow": true,
  "facility_code": "onprem initrd=initramfs-aarch64 console=ttyAMA0,115200 #",
  "ip_addresses": [
    {
      "enabled": true,
      "address_family": 4,
      "address": "$worker_ip_address",
      "netmask": "255.255.255.0",
      "gateway": "$provisioner_ip_address",
      "management": true,
      "public": false
    }
  ],
  "network_ports": [
    {
      "data": {
        "mac": "$worker_mac_address"
      },
      "name": "eth0",
      "type": "data"
    }
  ]
}
EOF
  docker exec -i deploy_tink-cli_1 tink hardware mac "$worker_mac_address" | jq .
  # create the workflow.
  workflow_output="$(docker exec -i deploy_tink-cli_1 tink workflow create -t "$template_id" -r "{\"device_1\": \"$worker_mac_address\", \"arch\": \"arm32v7\"}")"
  workflow_id="$(echo "$workflow_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
  docker exec -i deploy_tink-cli_1 tink workflow get "$workflow_id"
done
