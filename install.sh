#!/bin/sh

chown -R root:root *
chown -R 1000:1000 nix
chown -R 1000:1000 home/*

tar \
    --sort=name \
    --mtime='@1' \
    --numeric-owner \
    --hard-dereference \
    -c * > $out/wsl.tar
