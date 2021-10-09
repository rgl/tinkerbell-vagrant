#!/bin/bash
set -euxo pipefail
source /vagrant/tink-helpers.source.sh

# install dependencies.
apt-get install -y p7zip-full

# replace the current osie.
osie_current="$TINKERBELL_STATE_WEBROOT_PATH/misc/osie/current"
if [ ! -d "$osie_current.orig" ]; then
    mv "$osie_current" "$osie_current.orig"
fi
rm -rf "$osie_current"
mkdir -p "$osie_current"
pushd "$osie_current"
while read arch parch; do
    if [ -f /vagrant/tmp/tinkerbell-debian-osie-$arch.iso ]; then
        7z x /vagrant/tmp/tinkerbell-debian-osie-$arch.iso live/
        mv live/vmlinuz-*-$arch vmlinuz-$parch
        mv live/initrd.img-*-$arch initramfs-$parch
        mv live/filesystem.squashfs filesystem-$parch.squashfs
        rm -rf live
        ln -sf config.sh config-$parch.sh
    fi
done <<'EOF'
amd64 x86_64
arm64 aarch64
EOF
# create the live-config hook script that we can use to config the osie.
cat >config.sh <<'SCRIPT_EOF'
#!/bin/bash
set -euo pipefail

# NB you can see this script logs with jounalctl -u live-config.
# NB this file is executed synchronously by the live-config service
#    (/lib/systemd/system/live-config.service) from the
#    /lib/live/config/9990-hooks hook script.
# NB the systemd basic.target is only executed after this script
#    finishes (live-config.service has the WantedBy=basic.target
#    setting).
# NB normal services like containerd/dockerd/sshd are only be started
#    after this script finishes.

function get-param {
    cat /proc/cmdline | tr ' ' '\n' | grep "^$1=" | sed -E 's,.+=(.*),\1,g'
}

#systemctl disable --now tink-worker
SCRIPT_EOF
popd
pushd ~/tinkerbell-sandbox/deploy/compose
yq eval --inplace 'del(.services.osie-work)' docker-compose.yml
popd
