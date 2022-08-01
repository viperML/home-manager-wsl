{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs {},
}: let
  inherit (pkgs) lib;

  env = pkgs.buildEnv {
    name = "profile-env";
    paths = [
      pkgs.nix
      pkgs.bash
      pkgs.utillinux
      pkgs.coreutils
      (pkgs.runCommand "DELETEME" {} ''
        mkdir -p $out/etc
        cp -v ${./profile} $out/etc/profile
      '')
    ];
  };

  closureInfo = pkgs.closureInfo {
    rootPaths = [env];
  };

  prepare = {
    wsl = pkgs.writeShellScriptBin "prepare-wsl" ''
      mkdir -p $out
      mkdir -m 0755 bin
      mkdir -m 1777 tmp

      # WSL doesn't like these files as symlinks
      cp -av ${pkgs.pkgsStatic.bash}/bin/bash bin/sh
      cp -av ${pkgs.pkgsStatic.utillinux}/bin/mount bin/mount

      ln -sv nix/var/nix/profiles/default/etc etc
    '';
    store = pkgs.writeShellScriptBin "prepare-store" ''
      set -eux
      export NIX_REMOTE=local?root=$PWD
      export USER=nobody

      ${pkgs.nix}/bin/nix-store --load-db <${closureInfo}/registration
    '';
    profile = pkgs.writeShellScriptBin "prepare-profile" ''
      set -eux
      export NIX_REMOTE=local?root=$PWD
      export USER=nobody

      mkdir -p nix/var/nix/{profiles,gcroots/profiles}
      ${pkgs.nix}/bin/nix --extra-experimental-features "nix-command flakes" \
        profile install --offline --profile nix/var/nix/profiles/default ${env}


      while read -r file; do
        cp -av $file nix/store
      done < ${closureInfo}/store-paths

      rm -rv nix/var/nix/profiles/per-user/*
      rm -rf nix-*
      rm -v env-vars
    '';
  };

  tarball = pkgs.runCommand "tarball" {} ''
    ${lib.getExe prepare.store}
    ${lib.getExe prepare.profile}
    ${lib.getExe prepare.wsl}

    mkdir -p $out

    tar \
      --sort=name \
      --mtime='@1' \
      --owner=0 \
      --group=0 \
      --numeric-owner \
      --hard-dereference \
      -c * > $out/wsl.tar
  '';
in {
  inherit
    tarball
    env
    closureInfo
    ;
}
