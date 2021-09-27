#!/bin/bash
set -euo pipefail
cd /vagrant/actions

bash reboot/provision.sh
bash reset-uefi-boot/provision.sh
bash flatcar-install/provision.sh
