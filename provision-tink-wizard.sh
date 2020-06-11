#!/bin/bash
set -euxo pipefail

# clone the ipxe repo.
cd ~
[ -d tink-wizard ] || git clone https://github.com/rgl/tink-wizard.git tink-wizard
cd tink-wizard
git fetch origin feature-rgl-add-docker-compose
git checkout feature-rgl-add-docker-compose

# start it.
$SHELL /vagrant/start-tink-wizard.sh
docker-compose ps
