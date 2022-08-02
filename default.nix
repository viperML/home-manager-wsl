{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs {},
  toplevel ? throw "pass toplevel",
}: let
  inherit (pkgs) lib;

  closureInfo = pkgs.closureInfo {
    rootPaths = [];
  };

  alpine-tarball = pkgs.fetchurl {
    url = "https://dl-cdn.alpinelinux.org/alpine/v3.16/releases/x86_64/alpine-minirootfs-3.16.0-x86_64.tar.gz";
    hash = "sha256-ScsNBwKoveH3qhYg9T6XzqUUzlNUAQCBLBEZthKKQTQ=";
  };

  prepare = {
    alpine = pkgs.writeShellScriptBin "prepare-alpine" ''
      tar -xvf ${alpine-tarball}
      echo 'ayats:x:1000:1000::/home/ayats:/bin/sh' >> etc/passwd
      echo 'ayats:!::0:::::' >> etc/shadow
      mkdir -p home/ayats

      cp -av ${./wsl.conf} etc/wsl.conf
    '';
    store = pkgs.writeShellScriptBin "prepare-store" ''
      set -eux
      export NIX_REMOTE=local?root=$PWD
      export USER=nobody

      ${pkgs.nix}/bin/nix-store --load-db <${closureInfo}/registration
    '';
    # profile = pkgs.writeShellScriptBin "prepare-profile" ''
    #   set -eux
    #   export NIX_REMOTE=local?root=$PWD
    #   export USER=nobody

    #   mkdir -p nix/var/nix/{profiles,gcroots/profiles}

    #   ln -sv ${toplevel} nix/var/nix/profiles/system-1-link
    #   ln -sv system-1-link nix/var/nix/profiles/system

    #   while read -r file; do
    #     cp -av $file nix/store
    #   done < ${closureInfo}/store-paths
    # '';
    # cleanup = pkgs.writeShellScriptBin "prepare-cleanup" ''
    #   rm -rvf nix/var/nix/profiles/per-user/*
    #   rm -rf nix-*
    #   rm -fv env-vars
    # '';
  };

  tarball = pkgs.runCommand "tarball" {} ''
    ${lib.getExe prepare.alpine}
    ${lib.getExe prepare.store}

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
