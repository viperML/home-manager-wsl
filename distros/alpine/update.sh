#!/usr/bin/env bash

TEMP="$(mktemp -d)"
DIR="$(cd $(dirname $BASH_SOURCE); pwd)"


curl -o "$TEMP/latest-releases.yaml" -Ls "https://dl-cdn.alpinelinux.org/alpine/latest-stable/releases/x86_64/latest-releases.yaml"

RELEASE="$(yq -r '.[] | select( .flavor | contains("alpine-minirootfs") ) | .version' $TEMP/latest-releases.yaml)"
IFS=$'\n' read -d "" -ra arr <<< "${RELEASE//./$'\n'}"
MAJOR_RELEASE="$(printf ${arr[0]}.${arr[1]})"

tee "$TEMP/nvfetcher.toml" <<EOF
[rootfs]
src.manual = "$RELEASE"
fetch.url = "https://dl-cdn.alpinelinux.org/alpine/v$MAJOR_RELEASE/releases/x86_64/alpine-minirootfs-$RELEASE-x86_64.tar.gz"
EOF

nvfetcher \
    --config "$TEMP/nvfetcher.toml" \
    --build-dir "$DIR"
