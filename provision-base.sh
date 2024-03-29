#!/bin/bash
set -euxo pipefail

# configure apt for not asking interactive questions.
echo 'Defaults env_keep += "DEBIAN_FRONTEND"' >/etc/sudoers.d/env_keep_apt
chmod 440 /etc/sudoers.d/env_keep_apt
export DEBIAN_FRONTEND=noninteractive

# make sure grub can be installed in the current root disk.
# NB these anwsers were obtained (after installing grub-pc) with:
#
#   #sudo debconf-show grub-pc
#   sudo apt-get install debconf-utils
#   # this way you can see the comments:
#   sudo debconf-get-selections
#   # this way you can just see the values needed for debconf-set-selections:
#   sudo debconf-get-selections | grep -E '^grub-pc.+\s+' | sort
debconf-set-selections <<EOF
grub-pc	grub-pc/install_devices_disks_changed	multiselect	/dev/sda
grub-pc	grub-pc/install_devices	multiselect	/dev/sda
EOF


# disable IPv6.
cat >/etc/sysctl.d/98-disable-ipv6.conf <<'EOF'
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
EOF
systemctl restart procps
sed -i -E 's,(GRUB_CMDLINE_LINUX=.+)",\1 ipv6.disable=1",' /etc/default/grub
update-grub2


# upgrade the system.
apt-get update
apt-get dist-upgrade -y


#
# install tcpdump for being able to capture network traffic.

apt-get install -y tcpdump


#
# install vim.

apt-get install -y --no-install-recommends vim
cat >/etc/vim/vimrc.local <<'EOF'
syntax on
set background=dark
set esckeys
set ruler
set laststatus=2
set nobackup
EOF


#
# configure the shell.

cat >/etc/profile.d/login.sh <<'EOF'
[[ "$-" != *i* ]] && return # bail when not running interactively.
export EDITOR=vim
export PAGER=less
alias l='ls -lF --color'
alias ll='l -a'
alias h='history 25'
alias j='jobs -l'
EOF

cat >/etc/inputrc <<'EOF'
set input-meta on
set output-meta on
set show-all-if-ambiguous on
set completion-ignore-case on
"\e[A": history-search-backward
"\e[B": history-search-forward
"\eOD": backward-word
"\eOC": forward-word
EOF

cat >~/.bash_aliases <<'EOF'
source /vagrant/tink-helpers.source.sh
EOF

cat >~/.bash_history <<'EOF'
provision-workflow debian uefi && watch-hardware-workflows uefi
watch-hardware-workflows uefi
etherwake -i eth1 c0:3f:d5:6c:b7:5a
provision-workflow hello-world rpi1 && watch-hardware-workflows rpi1
watch-hardware-workflows rpi1
ssh pi@rpi1.test
ansible -f 10 -b -m command -a 'vcgencmd measure_temp' cluster
source /opt/ansible/bin/activate && cd /home/vagrant/rpi-cluster
EOF

# configure the vagrant user home.
su vagrant -c bash <<'EOF-VAGRANT'
set -euxo pipefail

install -d -m 750 ~/.ssh
cat /vagrant/tmp/id_rsa.pub /vagrant/tmp/id_rsa.pub >>~/.ssh/authorized_keys

cat >~/.bash_history <<'EOF'
ssh pi@rpi1.test
sudo su -l
EOF
EOF-VAGRANT


#
# setup NAT.
# see https://help.ubuntu.com/community/IptablesHowTo

apt-get install -y iptables iptables-persistent

# enable IPv4 forwarding.
sysctl net.ipv4.ip_forward=1
sed -i -E 's,^\s*#?\s*(net.ipv4.ip_forward=).+,\11,g' /etc/sysctl.conf

# NAT through eth0.
# NB use something like -s 10.10.10/24 to limit to a specific network.
iptables -t nat -A POSTROUTING -o eth0 -j MASQUERADE

# load iptables rules on boot.
iptables-save >/etc/iptables/rules.v4

# get the MAC vendor list (used by dhcp-lease-list(8)).
# NB the upstream is at http://standards-oui.ieee.org/oui/oui.txt
#    BUT linuxnet.ca version is better taken care of.
wget -qO- https://linuxnet.ca/ieee/oui.txt.bz2 | bzcat >/usr/local/etc/oui.txt


#
# provision the stgt iSCSI target (aka iSCSI server).
# see tgtd(8)
# see http://stgt.sourceforge.net/
# see https://tools.ietf.org/html/rfc7143
# TODO use http://linux-iscsi.org/ instead?
# TODO increase the nic MTU to be more iSCSI friendly.
# TODO use a dedicated VLAN for storage traffic. make it have higher priority then the others at the switch?

apt-get install -y --no-install-recommends tgt
systemctl status tgt


#
# provision useful tools.

apt-get install -y jq jo
apt-get install -y curl
apt-get install -y httpie
apt-get install -y unzip
apt-get install -y python3-tabulate python3-pem
apt-get install -y --no-install-recommends git
apt-get install -y make patch
apt-get install -y qemu-utils
apt-get install -y pigz

# install yq.
wget -qO- https://github.com/mikefarah/yq/releases/download/v4.12.2/yq_linux_amd64.tar.gz | tar xz
install yq_linux_amd64 /usr/local/bin/yq
rm yq_linux_amd64

# etherwake lets us power-on a machine by sending a Wake-on-LAN (WOL)
# magic packet to its ethernet card.
# e.g. etherwake -i eth1 c0:3f:d5:6c:b7:5a
apt-get install -y etherwake

# install clonezilla.
apt-get install -y --no-install-recommends clonezilla partclone zstd

# configure the system to automatically load nbd.
# NB this is required to use qemu-nbd.
cat >/etc/modules-load.d/nbd.conf <<'EOF'
nbd
EOF
cat >/etc/modprobe.d/nbd.conf <<'EOF'
options nbd max_part=8
EOF
modprobe nbd
