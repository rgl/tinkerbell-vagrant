#!/bin/bash
set -euxo pipefail

portainer_version="${1:-2.9.2}"; shift || true

docker volume create portainer_data
docker run \
  -d \
  -p 9000:9000 \
  --name=portainer \
  --restart=always \
  -v /var/run/docker.sock:/var/run/docker.sock \
  -v portainer_data:/data \
  portainer/portainer-ce:$portainer_version

# wait for portainer to be ready.
while [ -z "$(http --ignore-stdin localhost:9000/api/status | jq -r .Version)" ]; do sleep 3; done

# add the docker endpoint.
# see https://documentation.portainer.io/api/
http \
  --ignore-stdin \
  POST \
  localhost:9000/api/users/admin/init \
  Username=admin \
  Password=abracadabra \
  >/dev/null
authentication_token="$(http \
  --ignore-stdin \
  POST \
  localhost:9000/api/auth \
  Username=admin \
  Password=abracadabra \
  | jq -r .jwt)"
http \
  --ignore-stdin \
  --form \
  POST \
  localhost:9000/api/endpoints \
  "Authorization: Bearer $authentication_token" \
  Name=docker \
  EndpointCreationType=1 \
  >/dev/null
