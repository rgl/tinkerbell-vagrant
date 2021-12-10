#!/bin/bash
set -euxo pipefail

# install go.
# see https://golang.org/dl/
# see https://golang.org/doc/install
artifact_url=https://golang.org/dl/go1.17.4.linux-amd64.tar.gz
artifact_sha=adab2483f644e2f8a10ae93122f0018cef525ca48d0b8764dae87cb5f4fd4206
artifact_path="/tmp/$(basename $artifact_url)"
wget -qO $artifact_path $artifact_url
if [ "$(sha256sum $artifact_path | awk '{print $1}')" != "$artifact_sha" ]; then
    echo "downloaded $artifact_url failed the checksum verification"
    exit 1
fi
tar xf $artifact_path -C /usr/local
rm $artifact_path

# add go to all users path.
cat >/etc/profile.d/go.sh <<'EOF'
#[[ "$-" != *i* ]] && return
export PATH="$PATH:/usr/local/go/bin"
export PATH="$PATH:$HOME/go/bin"
EOF
