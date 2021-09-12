#!/bin/bash
set -euo pipefail
cd /vagrant/templates

bash hello-world/provision.sh
bash flatcar-linux/provision.sh

source /root/tink-helpers.source.sh
tink template get
