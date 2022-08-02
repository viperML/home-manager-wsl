#!/usr/bin/env bash
set -ex

NAME=nix

DIR="$(cd $(dirname $BASH_SOURCE); pwd)"

nix build "$DIR"#tarball -L
cp -fvL result/wsl.tar ~/Desktop/wsl.tar

set +e
wsl.exe --unregister $NAME || :
set -e

wsl.exe --import $NAME 'C:\WSL' 'C:\Users\ayats\Desktop\wsl.tar'
wsl.exe -d nix
