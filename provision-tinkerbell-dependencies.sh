#!/bin/bash
set -euxo pipefail

docker_version="${1:-5:19.03.11~3-0~ubuntu-focal}"; shift || true
docker_compose_version="${1:-1.26.0}"; shift || true

# prevent apt-get et al from opening stdin.
# NB even with this, you'll still get some warnings that you can ignore:
#     dpkg-preconfigure: unable to re-open stdin: No such file or directory
export DEBIAN_FRONTEND=noninteractive

# install the curl dependency.
apt-get install -y curl

# install the git dependency.
apt-get install -y --no-install-recommends git-core

# install the docker dependency.
# see https://docs.docker.com/install/linux/docker-ce/ubuntu/
apt-get install -y apt-transport-https software-properties-common gnupg2
wget -qO- https://download.docker.com/linux/ubuntu/gpg | apt-key add -
add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"
apt-get update
apt-get install -y "docker-ce=$docker_version" "docker-ce-cli=$docker_version" containerd.io
docker version

# install the docker-compose dependency.
# see https://github.com/docker/compose/releases
# see https://docs.docker.com/compose/install
wget -qO /usr/local/bin/docker-compose https://github.com/docker/compose/releases/download/$docker_compose_version/docker-compose-$(uname -s)-$(uname -m)
chmod +x /usr/local/bin/docker-compose
docker-compose --version
