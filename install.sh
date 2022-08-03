#!/bin/sh

chown -R root:root *
chown -R 1000:100 nix
chown -R 1000:100 home/*

rm -rf tmp
mkdir -m 1777 tmp

tar \
    --sort=name \
    --mtime='@1' \
    --gzip \
    --numeric-owner \
    --hard-dereference \
    -c * > $out/wsl.tar.gz
