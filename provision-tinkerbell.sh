#!/bin/bash
# abort this script on errors.
set -euxo pipefail

provisioner_ip_address="${1:-10.10.10.2}"; shift || true
tinkerbell_version="${1:-d9d6b637de27704714b179c0f2bf5f2b58b266ac}"; shift || true
worker_ip_address_prefix="$(echo $provisioner_ip_address | cut -d "." -f 1).$(echo $provisioner_ip_address | cut -d "." -f 2).$(echo $provisioner_ip_address | cut -d "." -f 3)"

# prevent apt-get et al from opening stdin.
# NB even with this, you'll still get some warnings that you can ignore:
#     dpkg-preconfigure: unable to re-open stdin: No such file or directory
export DEBIAN_FRONTEND=noninteractive

# install dependencies.
apt-get install -y curl

# remove the tput command because it breaks the vagrant execution.
apt-get remove --purge --allow-remove-essential -y ncurses-bin

# configure the network.
# NB if we do not configure the network setup.sh assumes we are using
#    /etc/network/interfaces to configure the system network, but
#    ubuntu 18.04+ uses netplan instead.
#    see https://github.com/tinkerbell/tink/issues/129
host_number="$(($(echo $provisioner_ip_address | cut -d "." -f 4 | xargs) + 1))"
nginx_ip_address="$(echo $provisioner_ip_address | cut -d "." -f 1).$(echo $provisioner_ip_address | cut -d "." -f 2).$(echo $provisioner_ip_address | cut -d "." -f 3).$host_number"
cat >/etc/netplan/60-eth1.yaml <<EOF
---
network:
  version: 2
  renderer: networkd
  ethernets:
    eth1:
      addresses:
        - $provisioner_ip_address/24
        - $nginx_ip_address/24
EOF
netplan apply
# wait for the network configuration to be applied by systemd-networkd.
while [ -z "$(ip addr show eth1 | grep "$nginx_ip_address/24")" ]; do
  sleep 1
done

# install tinkerbell.
# see https://github.com/tinkerbell/tink/blob/master/docs/setup.md
export TB_INTERFACE='eth1'
export TB_NETWORK="$provisioner_ip_address/24"
export TB_IPADDR="$provisioner_ip_address"
export TB_REGUSER='tinkerbell'
cd ~
wget -qO- https://raw.githubusercontent.com/tinkerbell/tink/$tinkerbell_version/setup.sh | bash -x

# install the workflows.
for d in /vagrant/workflows/*; do
  pushd $d
  $d/provision.sh
  popd
done

# show summary.
# e.g. inet 192.168.121.160/24 brd 192.168.121.255 scope global dynamic eth0
# NB this gets the IP of the vagrant management interface (eth0) because its
#    the only one accessible from the host (where libvirt is running) when
#    we are connecting eth1 to the linux bridge.
host_ip_address="$(ip addr show eth0 | perl -n -e'/ inet (\d+(\.\d+)+)/ && print $1')"
cat <<EOF

#################################################
#
# tink envrc
#

$(cat /root/tink/envrc)

#################################################
#
# addresses
#

kibana: http://$host_ip_address:5601

EOF
