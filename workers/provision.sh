#!/bin/bash
set -euxo pipefail
cd /vagrant/workers

bash provision-virtual.sh
bash provision-nuc.sh
bash provision-desktop-mini.sh

source /root/tink-helpers.source.sh
tink hardware get
