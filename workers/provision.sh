#!/bin/bash
set -euxo pipefail
cd /vagrant/workers

bash provision-virtual.sh
bash provision-rpis.sh
bash provision-nuc.sh
bash provision-desktop-mini.sh
bash provision-odyssey.sh

source /vagrant/tink-helpers.source.sh
tink hardware get
