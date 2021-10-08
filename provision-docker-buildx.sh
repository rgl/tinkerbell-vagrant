#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

# create a local buildx builder.
# TODO how to let it cache into the host so we can restart this container?
# install buildx dependencies.
apt-get install -y qemu-user-static

docker buildx create \
    --name local \
    --driver docker-container \
    --driver-opt network=host \
    --use
docker buildx inspect local --bootstrap

# configure the buildx container to trust our local tinkerbell created registry ca.
# see https://github.com/docker/buildx/issues/80
# TODO instead of patching the container, try to create a new image from the
#      buildkit base image (moby/buildkit:buildx-stable-1) that includes our
#      changes, then create the builder using that image (--driver-opt
#      image=my-builder-image).
buildx_builder='buildx_buildkit_local0'
docker cp /usr/local/share/ca-certificates/tinkerbell.crt $buildx_builder:/usr/local/share/ca-certificates
# NB the "WARNING: ca-certificates.crt does not contain exactly one certificate or CRL: skipping" warning is normal, and can be safely ignored.
docker exec $buildx_builder update-ca-certificates -v
docker restart $buildx_builder
