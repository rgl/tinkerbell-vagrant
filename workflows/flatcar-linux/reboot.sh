#!/bin/sh
set -euxo pipefail

# NB this way of doing reboot is too harsh as it does not flush any cache; but
#    there is no other way right now to reboot tink-worker.
#    see https://github.com/tinkerbell/tink/issues/71
docker run \
    --detach \
    --privileged \
    --entrypoint '' \
    $REGISTRY/reboot \
    sh -c 'sleep 30 && echo 1 >/proc/sys/kernel/sysrq && echo b >/proc/sysrq-trigger'

echo 'Rebooting in 30s...'
