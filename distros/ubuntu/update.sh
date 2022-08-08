#!/usr/bin/env bash
set -x

TEMP="$(mktemp -d)"
DIR="$(
	cd $(dirname $BASH_SOURCE)
    pwd
)"

curl -o "$TEMP/released.txt" -Ls https://cloud-images.ubuntu.com/query/released.latest.txt

RELEASE_NAME="$(tail $TEMP/released.txt -n1 | awk '{print $1}')"
RELEASE_CODE="$(tail $TEMP/released.txt -n1 | awk '{print $4}')"

# RELEASE="$(yq -r '.[] | select( .flavor | contains("alpine-minirootfs") ) | .version' $TEMP/latest-releases.yaml)"
# IFS=$'\n' read -d "" -ra arr <<< "${RELEASE//./$'\n'}"
# MAJOR_RELEASE="$(printf ${arr[0]}.${arr[1]})"

tee "$TEMP/nvfetcher.toml" <<EOF
[rootfs]
src.manual = "$RELEASE_NAME-$RELEASE_CODE"
fetch.url = "https://cloud-images.ubuntu.com/$RELEASE_NAME/$RELEASE_CODE/$RELEASE_NAME-server-cloudimg-amd64-wsl.rootfs.tar.gz"
EOF

nvfetcher \
	--config "$TEMP/nvfetcher.toml" \
	--build-dir "$DIR"
