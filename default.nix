{
  nixpkgs ? <nixpkgs>,
  pkgs ? import nixpkgs {},
  toplevel ? throw "pass toplevel",
}: let
  inherit (pkgs) lib;

  closureInfo = pkgs.closureInfo {
    rootPaths = [toplevel];
  };

  prepare = {
    wsl = pkgs.writeShellScriptBin "prepare-wsl" ''
      mkdir -p $out
      mkdir -m 0755 bin etc
      mkdir -m 1777 tmp

      # WSL doesn't like these files as symlinks
      cp -av ${pkgs.pkgsStatic.bashInteractive}/bin/bash bin/sh
      cp -av ${pkgs.pkgsStatic.utillinux}/bin/mount bin/mount

      tee bashrc <<EOF
      export PATH="${lib.makeBinPath [pkgs.coreutils-full]}:/nix/var/nix/profiles/system/sw/bin:$PATH"
      source ${pkgs.bash-completion}/etc/profile.d/bash_completion.sh
      EOF

      cp -av ${./wsl.conf} etc/wsl.conf
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

      ln -sv ${toplevel} nix/var/nix/profiles/system-1-link
      ln -sv system-1-link nix/var/nix/profiles/system

      while read -r file; do
        cp -av $file nix/store
      done < ${closureInfo}/store-paths
    '';
    cleanup = pkgs.writeShellScriptBin "prepare-cleanup" ''
      rm -rvf nix/var/nix/profiles/per-user/*
      rm -rf nix-*
      rm -fv env-vars
    '';
  };

  tarball = pkgs.runCommand "tarball" {} ''
    ${lib.getExe prepare.store}
    ${lib.getExe prepare.profile}
    ${lib.getExe prepare.wsl}
    ${lib.getExe prepare.cleanup}

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
    closureInfo
    ;
}
