#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

cd "$(dirname "${BASH_SOURCE[0]}")"

hardware_hostname="$1"

# find the hardware with the given hostname.
hardware_mac="$(get-hardware-mac "$hardware_hostname")"

# find the template id.
template_id="$(tink template get --format json | jq -r '.data[] | select(.name=="hello-world") | .id')"

# delete the workflows associated with the hardware.
delete-hardware-workflows "$hardware_hostname"

# create the workflow.
hardware="$(jo device_1=$hardware_mac)"
workflow_output="$(tink workflow create --template "$template_id" --hardware "$hardware")"
workflow_id="$(echo "$workflow_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
tink workflow get "$workflow_id"
