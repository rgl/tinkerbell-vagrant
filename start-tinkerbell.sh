#!/bin/bash

source /root/tink/envrc

# start stopped containers.
# see https://github.com/tinkerbell/tink/issues/161
# NB we do not start the certs container as it breaks things.
# NB docker-compose -f /root/tink/deploy/docker-compose.yml start does not seem to be enough.
docker ps -a --format 'table {{.CreatedAt}}\t{{.Names}}\t{{.Status}}' \
  | grep -E 'deploy_.+_1.+Exited' \
  | grep -v deploy_certs_1 \
  | sort \
  | awk '{print $5}' \
  | xargs -I% docker start %
