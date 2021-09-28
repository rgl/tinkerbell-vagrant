#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh
cd "$(dirname "${BASH_SOURCE[0]}")"

# create the template.
delete-template windows-2022
template_output="$(cat workflow-template.yml | tink template create)"
template_id="$(echo "$template_output" | perl -n -e '/([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})/ && print $1')"
tink template get "$template_id"
