#!/bin/bash
set -euxo pipefail

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

kibana:         http://$host_ip_address:5601
tink-wizard:    http://$host_ip_address:7676

EOF
