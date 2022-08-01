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
    ];
  };

  closureInfo = pkgs.closureInfo {
    rootPaths = [env];
  };

  prepare-store = pkgs.writeShellScriptBin "prepare-store" ''
    set -eux
    export NIX_REMOTE=local?root=$PWD
    export USER=nobody

    ${pkgs.nix}/bin/nix-store --load-db <${closureInfo}/registration
  '';

  prepare-profile = pkgs.writeShellScriptBin "prepare-profile" ''
    set -eux
    export NIX_REMOTE=local?root=$PWD
    export USER=nobody

    mkdir -p nix/var/nix/{profiles,gcroots/profiles}
    ${pkgs.nix}/bin/nix --extra-experimental-features "nix-command flakes" \
      profile install --offline --profile nix/var/nix/profiles/system ${env}

    # rm -rv nix/var/nix/profiles/per-user/*
    # rm -rf nix-*


    while read -r file; do
      cp -av $file nix/store
    done < ${closureInfo}/store-paths

    rm -v env-vars
    rm -rv nix-*
  '';

  prepare-static = pkgs.writeShellScriptBin "prepare-static" ''
    mkdir -p $out
    mkdir -m 0755 bin etc
    mkdir -m 1777 tmp

    cp -av ${pkgs.pkgsStatic.bash}/bin/bash bin/sh
    cp -av ${pkgs.pkgsStatic.utillinux}/bin/mount bin/mount
  '';

  tarball = pkgs.runCommand "tarball" {} ''
    ${lib.getExe prepare-static}
    ${lib.getExe prepare-store}
    ${lib.getExe prepare-profile}

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
  # tarball = pkgs.callPackage "${nixpkgs}/nixos/lib/make-system-tarball.nix" {
  #   contents = [];
  #   fileName = "wsl";
  #   storeContents = pkgs2storeContents [
  #     env
  #   ];
  #   compressCommand = "gzip";
  #   compressionExtension = ".gz";
  #   extraInputs = [];
  #   # extraArgs = "--transform s,^,./,";
  #   extraCommands =
  #     (pkgs.writeShellScript "extraCommands" ''
  #       ${lib.getExe prepare-store}
  #       ${lib.getExe prepare-alpine}
  #     '')
  #     .outPath;
  # };
in {
  inherit
    tarball
    env
    closureInfo
    ;
}
