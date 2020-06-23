#!/bin/bash
# abort this script on errors.
set -euxo pipefail

provisioner_ip_address="${1:-10.10.10.2}"; shift || true
tinkerbell_version="${1:-4e59b92cdafcd964e5a07a08df455c0b384c5782}"; shift || true
worker_ip_address_prefix="$(echo $provisioner_ip_address | cut -d "." -f 1).$(echo $provisioner_ip_address | cut -d "." -f 2).$(echo $provisioner_ip_address | cut -d "." -f 3)"
host_number="$(($(echo $provisioner_ip_address | cut -d "." -f 4 | xargs) + 1))"
nginx_ip_address="$(echo $provisioner_ip_address | cut -d "." -f 1).$(echo $provisioner_ip_address | cut -d "." -f 2).$(echo $provisioner_ip_address | cut -d "." -f 3).$host_number"
tinkerbell_interface='eth1'

# install tinkerbell.
# see https://github.com/tinkerbell/tink/blob/master/docs/setup.md
cd ~
git clone https://github.com/tinkerbell/tink.git
cd tink
git reset --hard $tinkerbell_version
bash -eu generate-envrc.sh $tinkerbell_interface >envrc
sed -i -E "s,(TINKERBELL_CIDR)=.+,\\1=24,g" envrc
sed -i -E "s,(TINKERBELL_HOST_IP)=.+,\\1=$provisioner_ip_address,g" envrc
sed -i -E "s,(TINKERBELL_NGINX_IP)=.+,\\1=$nginx_ip_address,g" envrc
sed -i -E "s,(TINKERBELL_REGISTRY_USERNAME)=.+,\\1=tinkerbell,g" envrc
mkdir -p /etc/docker/certs.d/$provisioner_ip_address
bash -eux setup.sh

# start tinkerbell.
bash -eux /vagrant/start-tinkerbell.sh

# install the workflows.
for d in /vagrant/workflows/*; do
  pushd $d
  $d/provision.sh
  popd
done
