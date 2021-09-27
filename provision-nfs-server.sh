#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

ip_address="$(ip add show eth1 | perl -n -e '/^\s+inet (\d+(\.\d+)+)/ && print $1')"

#
# provision the NFS server.
# see exports(5).

apt-get install -y nfs-kernel-server

# configure the images export.
install -d -o nobody -g nogroup -m 700 /var/nfs/images
chmod 755 /root # NB our images come from a sub-directry in this tree.
install -d $TINKERBELL_STATE_WEBROOT_PATH/images
cat >>/etc/fstab <<EOF
$TINKERBELL_STATE_WEBROOT_PATH/images /var/nfs/images none bind,ro 0 0
EOF
mount /var/nfs/images
install -d /etc/exports.d
cat >/etc/exports.d/images.exports <<EOF
/var/nfs/images $ip_address/24(ro,no_subtree_check,all_squash)
EOF
exportfs -arv

# dump the supported nfs versions.
cat /proc/fs/nfsd/versions | tr ' ' "\n" | grep '^+' | tr '+' 'v'

# test access to the NFS server using NFSv3 (UDP and TCP) and NFSv4 (TCP).
exportfs -s
showmount -e $ip_address
rpcinfo -u $ip_address nfs 3
rpcinfo -t $ip_address nfs 3
rpcinfo -t $ip_address nfs 4
