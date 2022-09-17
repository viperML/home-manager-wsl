#!/usr/bin/env bash
set -ex

CONFIG="${1:-sample}"

NAME=nix

DIR="$(cd $(dirname $BASH_SOURCE)/..; pwd)"

nix build "$DIR#homeConfigurations.$CONFIG.config.wsl.tarball" -L
cp -fvL result/*.tar* ~/Desktop/wsl.tar.gz

set +e
wsl.exe --unregister $NAME || :
set -e

wsl.exe --import $NAME "C:\WSL\\$NAME" "C:\Users\\$USER\Desktop\\wsl.tar.gz"
wsl.exe -d nix
