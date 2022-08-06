#!/usr/bin/env bash
set -ex

NAME=nix

DIR="$(cd $(dirname $BASH_SOURCE)/..; pwd)"

FILENAME=$(nix eval --raw $DIR#homeConfigurations.sample.config.home.wsl.tarballName)
nix build "$DIR"#homeConfigurations.sample.config.home.wsl.tarball -L
cp -fvL result/$FILENAME ~/Desktop/$FILENAME

set +e
wsl.exe --unregister $NAME || :
set -e

wsl.exe --import $NAME "C:\WSL\\$NAME" "C:\Users\\$USER\Desktop\\$FILENAME"
wsl.exe -d nix
