#!/bin/bash
# abort this script on errors.
set -euxo pipefail

provisioner_ip_address="${1:-10.3.0.2}"; shift || true

# install tinkerbell.
# see https://docs.tinkerbell.org/setup/on-bare-metal-with-docker/
# see https://github.com/rgl/tinkerbell-tink
tinkerbell_repository='https://github.com/tinkerbell/sandbox.git'
tinkerbell_version='41cc30f01c5c53a306f6ca86d426147edd00aff0' # 2021-09-08T16:38:30Z
cd ~
git clone --no-checkout $tinkerbell_repository tinkerbell-sandbox
cd tinkerbell-sandbox
git checkout -f $tinkerbell_version
cd deploy/compose
sed -i -E "s,(TINKERBELL_HOST_IP)=.*,\\1=$provisioner_ip_address,g" .env
yq eval --inplace 'del(.services.create-tink-records)' docker-compose.yml
yq eval --inplace 'del(.services.ubuntu-image-setup)' docker-compose.yml
yq eval --inplace 'del(.services.osie-bootloader.depends_on.ubuntu-image-setup)' docker-compose.yml
docker compose pull --quiet
docker compose run tls-gen
docker compose up --quiet-pull --detach registry

# trust the tinkerbell registry ca.
# NB this is required to docker push our images.
# NB we must restart docker for it to pick up the new certificate.
# NB we must restart docker before we start tinkerbell, as we cannot interrupt
#    the images-to-local-registry service before it finishes.
source .env
docker compose cp registry:/certs/onprem/bundle.pem /usr/local/share/ca-certificates/tinkerbell.crt
update-ca-certificates
systemctl restart docker
docker login $TINKERBELL_HOST_IP --username admin --password-stdin <<EOF
Admin1234
EOF

# start tinkerbell.
docker compose up --quiet-pull --detach
