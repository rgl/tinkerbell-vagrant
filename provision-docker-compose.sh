#!/bin/bash
set -euxo pipefail

docker_compose_version="${1:-v2.0.1}"; shift || true

# download.
# see https://github.com/docker/compose/releases
# see https://docs.docker.com/compose/cli-command/#install-on-linux
docker_compose_url="https://github.com/docker/compose/releases/download/$docker_compose_version/docker-compose-linux-$(uname -m)"
wget -qO /tmp/docker-compose "$docker_compose_url"

# install.
install -d ~/.docker/cli-plugins
install -m 555 /tmp/docker-compose ~/.docker/cli-plugins
rm /tmp/docker-compose
docker compose version
