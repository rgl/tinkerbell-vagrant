#!/bin/bash
set -euo pipefail
cd /vagrant/templates

bash debian/provision.sh
bash flatcar-linux/provision.sh
bash hello-world/provision.sh
bash proxmox-ve/provision.sh
bash ubuntu/provision.sh
bash windows-2022/provision.sh

source /vagrant/tink-helpers.source.sh
tink template get
