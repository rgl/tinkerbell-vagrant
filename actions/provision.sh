#!/bin/bash
set -euo pipefail
cd /vagrant/actions

bash reboot/provision.sh
bash flatcar-install/provision.sh
