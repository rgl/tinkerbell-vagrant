#!/bin/bash
set -euo pipefail
source /vagrant/tink-helpers.source.sh

function title {
    cat <<EOF

########################################################################
#
# $*
#

EOF
}

# list the images in our local registry.
# TODO why some of them do not have the $TINKERBELL_HOST_IP/tinkerbell prefix?
title 'local repository images'
curl -s -u "${TINKERBELL_REGISTRY_USERNAME:-admin}:${TINKERBELL_REGISTRY_PASSWORD:-Admin1234}" \
    "https://$TINKERBELL_HOST_IP/v2/_catalog" \
    | jq -r '.repositories[]' \
    | while read repository; do
        curl -s -u "${TINKERBELL_REGISTRY_USERNAME:-admin}:${TINKERBELL_REGISTRY_PASSWORD:-Admin1234}" \
            "https://$TINKERBELL_HOST_IP/v2/$repository/tags/list" \
            | jq -r 'select(has("tags")) | .tags[]' \
            | while read tag; do
                echo "$TINKERBELL_HOST_IP/$repository:$tag"
            done
    done

# show tink resources.
title 'tink hardware'
tink hardware get

title 'tink template'
tink template get

# TODO instead of this, show a table with:
#       workflow id, template name, state, mac address, ip address, hostname.
title 'tink workflow'
tink workflow get

title 'tink .env'
cat /root/tinkerbell-sandbox/deploy/compose/.env

title 'addresses'
# e.g. inet 192.168.121.160/24 brd 192.168.121.255 scope global dynamic eth0
host_ip_address="$(ip addr show eth1 | perl -n -e'/ inet (\d+(\.\d+)+)/ && print $1')"
python3 <<EOF
from tabulate import tabulate

headers = ('service', 'address', 'username', 'password')

def info():
    yield ('meshcommander',    'http://$host_ip_address:4000', None, None)
    yield ('portainer',        'http://$host_ip_address:9000', 'admin', 'abracadabra')
    yield ('tinkerbell-nginx', 'http://$host_ip_address:8080', None, None)

print(tabulate(info(), headers=headers))
EOF
