#!/bin/bash
set -euxo pipefail

source /root/tink/envrc

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
template_output="$(cat workflow-template.yml | docker exec -i deploy_tink-cli_1 tink template create --name flatcar-linux)"
template_id="$(echo "$template_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
docker exec -i deploy_tink-cli_1 tink template get "$template_id"

# create the x86_64 machines workers hardware and respective workflow.
# see https://tinkerbell.org/hardware-data/
# see type HardwareTinkerbellV1 at https://github.com/tinkerbell/boots/blob/b88dc4e644701b5a946e5e6dee5888b2503294f7/packet/models.go#L101-L106
workers=(
  "c0:3f:d5:6c:b7:5a $worker_ip_address_prefix.13 nuc true"   # my nuc physical machine.
)
for worker in "${workers[@]}"; do
  export worker_mac_address="$(echo "$worker" | awk '{print $1}')"
  export worker_ip_address="$(echo "$worker" | awk '{print $2}')"
  export worker_name="$(echo "$worker" | awk '{print $3}')"
  export worker_efi_boot="$(echo "$worker" | awk '{print $4}')"
  export worker_id="00000000-0000-4000-8000-$(echo -n "$worker_mac_address" | tr -d :)"
  # create the hardware.
  cat hardware-template.json | DOLLAR='$' envsubst | docker exec -i deploy_tink-cli_1 tink hardware push
  docker exec -i deploy_tink-cli_1 tink hardware mac "$worker_mac_address" | jq .
  # create the workflow.
  ignition="$(cat flatcar-linux-config.yml | CORE_SSH_PUBLIC_KEY="$(cat /vagrant/tmp/id_rsa.pub)" DOLLAR='$' envsubst | ./tmp/ct | base64 -w0)"
  hardware="$(jo device_1=$worker_mac_address ignition=$ignition registry=$provisioner_ip_address arch=x86_64)"
  workflow_output="$(docker exec -i deploy_tink-cli_1 tink workflow create --template "$template_id" --hardware "$hardware")"
  workflow_id="$(echo "$workflow_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
  docker exec -i deploy_tink-cli_1 tink workflow get "$workflow_id"
done
