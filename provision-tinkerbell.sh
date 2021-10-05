#!/bin/bash
# abort this script on errors.
set -euxo pipefail

provisioner_ip_address="${1:-10.3.0.2}"; shift || true

# install tinkerbell.
# see https://docs.tinkerbell.org/setup/on-bare-metal-with-docker/
# see https://github.com/tinkerbell/sandbox
# see https://github.com/rgl/tinkerbell-tink
tinkerbell_repository='https://github.com/tinkerbell/sandbox.git'
tinkerbell_version='41a7ae3c6040c909bd1a496412936aea01fed260' # 2021-10-04T21:07:07Z
cd ~
git clone --no-checkout $tinkerbell_repository tinkerbell-sandbox
cd tinkerbell-sandbox
git checkout -f $tinkerbell_version
cd deploy/compose
sed -i -E "s,(TINKERBELL_HOST_IP)=.*,\\1=$provisioner_ip_address,g" .env
yq eval --inplace 'del(.services.create-tink-records)' docker-compose.yml
yq eval --inplace 'del(.services.ubuntu-image-setup)' docker-compose.yml
yq eval --inplace 'del(.services.osie-bootloader.depends_on.ubuntu-image-setup)' docker-compose.yml
yq eval --inplace '.services.osie-bootloader.volumes += ["./osie-bootloader/nginx-templates:/etc/nginx/templates:ro"]' docker-compose.yml
install -d osie-bootloader/nginx-templates
# NB autoindex is required by httpdirfs to mount an http filesystem.
cat >osie-bootloader/nginx-templates/default.conf.template <<'EOF'
server {
    location / {
        root /usr/share/nginx/html;
        autoindex on;
    }
}
EOF
docker compose pull --quiet
docker compose run tls-gen
docker compose up --quiet-pull --detach registry

# trust the tinkerbell registry ca.
# NB this is required to docker push our images.
# NB we must restart docker for it to pick up the new certificate.
# NB we must restart docker before we start tinkerbell, as we cannot interrupt
#    the images-to-local-registry service before it finishes.
source .env
docker compose cp registry:/certs/onprem/bundle.pem /tmp/bundle.pem
python3 >/usr/local/share/ca-certificates/tinkerbell.crt <<'EOF'
import sys
import pem

# extract the ca certificate from the bundle.
certificates = pem.parse_file('/tmp/bundle.pem')
print(certificates[-1])
EOF
update-ca-certificates
systemctl restart docker
docker login $TINKERBELL_HOST_IP --username admin --password-stdin <<EOF
Admin1234
EOF

# start tinkerbell.
docker compose up --quiet-pull --detach
