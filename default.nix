{
  pkgs ? import <nixpkgs> {},
}: let
  inherit (pkgs) lib;

  bootstrapEnv = pkgs.buildEnv {
    name = "bootstrap-env";
    paths = [
      pkgs.nix
      pkgs.coreutils-full
    ];
  };

  closureInfo = pkgs.closureInfo {
    rootPaths = [
      bootstrapEnv
    ];
  };

  alpineVersion = "3.16.0";

  alpine-tarball = pkgs.fetchurl {
    url = "https://dl-cdn.alpinelinux.org/alpine/v3.16/releases/x86_64/alpine-minirootfs-${alpineVersion}-x86_64.tar.gz";
    hash = "sha256-ScsNBwKoveH3qhYg9T6XzqUUzlNUAQCBLBEZthKKQTQ=";
  };

  extraAlpinePackages = [
    (pkgs.fetchurl {
      url = "https://dl-cdn.alpinelinux.org/alpine/v3.16/community/x86_64/sudo-1.9.10-r0.apk";
      hash = "sha256-FO7zBXOLX4IO5GWDkWW3PU9ZMFsV1SiO8FtcbEat15U=";
    })
  ];

  runBwrap = command: ''
    ${pkgs.bubblewrap}/bin/bwrap \
      --bind $PWD / \
      --uid 0 \
      --gid 0 \
      -- ${command}
  '';

  prepare = {
    alpine = pkgs.writeShellScriptBin "prepare-alpine" ''
      tar -xvf ${alpine-tarball}
      cp -av ${./etc}/* etc

      ${lib.concatMapStringsSep "\n" (p: "${pkgs.apk-tools}/bin/apk add --root $PWD --allow-untrusted ${p}") extraAlpinePackages}

      ${runBwrap "/usr/sbin/adduser -h /home/ayats -s /bin/sh -G users -D ayats"}
      ${runBwrap "/usr/sbin/addgroup ayats wheel"}
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

      ln -sv ${bootstrapEnv} nix/var/nix/profiles/bootstrap-1-link
      ln -sv bootstrap-1-link nix/var/nix/profiles/bootstrap

      while read -r file; do
        cp -av $file nix/store
      done < ${closureInfo}/store-paths
    '';
    # cleanup = pkgs.writeShellScriptBin "prepare-cleanup" ''
    #   rm -rvf nix/var/nix/profiles/per-user/*
    #   rm -rf nix-*
    #   rm -fv env-vars
    # '';
  };

  tarball = pkgs.runCommand "tarball" {} ''
    ${lib.getExe prepare.alpine}
    ${lib.getExe prepare.store}
    ${lib.getExe prepare.profile}

    mkdir -p $out

    ${pkgs.fakeroot}/bin/fakeroot sh -c ${./install.sh}
  '';
in {
  inherit
    tarball
    closureInfo
    alpine-tarball
    ;
}
