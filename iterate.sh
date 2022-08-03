#!/usr/bin/env bash
set -ex

NAME=nix

DIR="$(cd $(dirname $BASH_SOURCE); pwd)"

nix build "$DIR"#homeConfigurations.sample.config.home.wsl.tarball -L
cp -fvL result/wsl.tar.gz ~/Desktop/wsl.tar.gz

set +e
wsl.exe --unregister $NAME || :
set -e

wsl.exe --import $NAME 'C:\WSL' 'C:\Users\ayats\Desktop\wsl.tar.gz'
wsl.exe -d nix
