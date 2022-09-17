#!/usr/bin/env bash
set -x

TEMP="$(mktemp -d)"
DIR="$(
	cd $(dirname $BASH_SOURCE)
    pwd
)"


RELEASE="22.04"
BUILD="$(curl -Ls https://cloud-images.ubuntu.com/releases/$RELEASE | grep -oE 'href="release-[0-9]+/"' | grep -oE '[0-9]+' | tail -n1)"

tee "$TEMP/nvfetcher.toml" <<EOF
[rootfs]
src.manual = "$RELEASE-$BUILD"
fetch.url = "https://cloud-images.ubuntu.com/releases/$RELEASE/release-$BUILD/ubuntu-$RELEASE-server-cloudimg-amd64-wsl.rootfs.tar.gz"
EOF

nvfetcher \
	--config "$TEMP/nvfetcher.toml" \
	--build-dir "$DIR"
