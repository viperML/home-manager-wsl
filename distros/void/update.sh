#!/usr/bin/env -S nix shell nixpkgs#htmlq -c bash

TEMP="$(mktemp -d)"
DIR="$(cd $(dirname $BASH_SOURCE); pwd)"


curl -o "$TEMP/releases.html" -Ls "https://repo-default.voidlinux.org/live"

_RELEASE="$(htmlq --attribute href a -f $TEMP/releases.html | sort -n | tail -1)"
RELEASE="${_RELEASE//'/'}"

echo $RELEASE

tee "$TEMP/nvfetcher.toml" <<EOF
[rootfs]
src.manual = "$RELEASE"
fetch.url = "https://repo-default.voidlinux.org/live/$RELEASE/void-x86_64-ROOTFS-$RELEASE.tar.xz"
EOF

nvfetcher \
    --config "$TEMP/nvfetcher.toml" \
    --build-dir "$DIR"
