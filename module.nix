args @ {
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  # Based on https://github.com/nix-community/home-manager/blob/2f58d0a3de97f4c20efcc6ba00878acfd7b5665d/modules/files.nix#L171
  link = pkgs.writeShellScript "link" ''
    newGenFiles="$1"
    shift
    for sourcePath in "$@" ; do
      relativePath="''${sourcePath#$newGenFiles/}"
      targetPath="$HOME/$relativePath"
      if [[ -e "$targetPath" && ! -L "$targetPath" ]] && cmp -s "$sourcePath" "$targetPath" ; then
        # The target exists but is identical – don't do anything.
        "Skipping '$targetPath' as it is identical to '$sourcePath'"
      else
        # Place that symlink, --force
        mkdir -p -v "$(dirname "$targetPath")"
        ln -nsf -v "$sourcePath" "$targetPath"
      fi
    done
  '';
  closureInfo = pkgs.closureInfo {
    rootPaths = [
      config.home.path
      config.home.activationPackage
    ];
  };
  fakeroot-install-script = pkgs.writeShellScript "fakeroot-install-script" ''
    chown -R root:root *
    chown -R 1000:100 nix
    chown -R 1000:100 home/*

    rm -rf tmp
    mkdir -m 1777 tmp

    echo "Creating tarball, don't panic if it looks stuck"
    tar \
        --sort=name \
        --mtime='@1' \
        --gzip \
        --numeric-owner \
        --hard-dereference \
        -c * > $out/${config.home.wsl.tarballName}
  '';
in {
  options.home.wsl = {
    tarball = mkOption {
      internal = true;
      type = types.package;
      description = "Package containing the WSL tarball";
      readOnly = true;
      visible = true;
    };
    tarballName = mkOption {
      type = types.str;
      description = "Filename to give to the buildable tarball";
    };
    provisionScripts = mkOption {
      internal = true;
      type = with types; listOf package;
      description = "Scripts to run when creating the tarball";
    };
    extraProvisionScripts = mkOption {
      type = with types; listOf package;
      description = "Scripts to run when creating the tarball";
      default = [];
    };
    packages = mkOption {
      type = with types; listOf package;
      description = "Extra packages to cover alpine's packages";
      # Based on:
      # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/config/system-path.nix#L10
      default = with pkgs; [
        bashInteractive
        bzip2
        coreutils-full
        cpio
        curl
        diffutils
        findutils
        gawk
        getconf
        getent
        gnugrep
        gnupatch
        gnused
        gnutar
        gzip
        less
        libcap
        ncurses
        netcat
        procps
        time
        utillinux
        which
        xz
        zstd
      ];
    };
    baseDistro = mkOption {
      type = types.str;
      description = "Linux distribution to use as a base";
      default = "alpine";
    };
    conf = mkOption {
      type = with types; attrsOf (attrsOf (oneOf [string int bool]));
      description = "Configuration to write to /etc/wsl.conf";
    };
    package-wsl-conf = mkOption {
      type = types.package;
      internal = true;
    };
  };

  config = {
    home.packages =
      config.home.wsl.packages
      ++ [
        config.home.wsl.package-wsl-conf
      ];
    home.wsl = {
      conf = {
        user.default = config.home.username;
      };
      package-wsl-conf = pkgs.runCommand "wsl-conf" {} ''
        mkdir -p $out/etc
        tee $out/etc/wsl.conf <<EOF
        ${generators.toINI {} config.home.wsl.conf}EOF
      '';
      provisionScripts = [
        (import ./distros/${config.home.wsl.baseDistro} args)
        (pkgs.writeShellScript "prepare-wsl" ''
          ln -s /nix/var/nix/profiles/per-user/${config.home.username}/profile/etc/wsl.conf etc/wsl.conf
        '')
        (pkgs.writeShellScript "prepare-store" ''
          set -eux
          export NIX_REMOTE=local?root=$PWD
          export USER=nobody

          ${pkgs.nix}/bin/nix-store --load-db <${closureInfo}/registration
        '')
        (pkgs.writeShellScript "prepare-profile" ''
          set -eux
          export NIX_REMOTE=local?root=$PWD
          export USER=nobody

          mkdir -p nix/var/nix/{profiles,gcroots/profiles}

          while read -r file; do
            cp -a $file nix/store
          done < ${closureInfo}/store-paths

          mkdir -p nix/var/nix/profiles/per-user/${config.home.username}

          ${pkgs.nix}/bin/nix-env \
            --install \
            --prebuilt-only \
            --profile nix/var/nix/profiles/per-user/${config.home.username}/profile \
            ${config.home.path}

          ln -s /nix/var/nix/profiles/per-user/${config.home.username}/profile .${config.home.homeDirectory}/.nix-profile

          ln -s ${config.home.activationPackage} nix/var/nix/profiles/per-user/${config.home.username}/home-manager-1-link
          ln -s home-manager-1-link nix/var/nix/profiles/per-user/${config.home.username}/home-manager

          chmod +w etc/profile.d
          ln -s /nix/var/nix/profiles/per-user/${config.home.username}/profile/etc/profile.d/nix.sh etc/profile.d/nix.sh
          ln -s /nix/var/nix/profiles/per-user/${config.home.username}/profile/etc/profile.d/hm-session-vars.sh etc/profile.d/hm-session-vars.sh

          export VERBOSE=1
          export HOME=$PWD${config.home.homeDirectory}
          export USER=${config.home.username}
          export PATH="${lib.makeBinPath [pkgs.nix]}:$PATH"

          newGenFiles="$(readlink -e "${config.home.activationPackage}/home-files")"
          find "$newGenFiles" \( -type f -or -type l \) \
            -exec bash ${link} "$newGenFiles" {} +
        '')
        (pkgs.writeShellScript "prepare-cleanup" ''
          rm -rvf nix/var/nix/profiles/per-user/nixbld
          rm -rf nix-*
          rm -fv env-vars
          rm -rf nix/var/nix/gcroots/auto/*
        '')
      ];
      tarball = pkgs.runCommand "tarball" {} ''
        ${concatStringsSep "\n" config.home.wsl.provisionScripts}
        ${concatStringsSep "\n" config.home.wsl.extraProvisionScripts}

        mkdir -p $out
        ${pkgs.fakeroot}/bin/fakeroot sh -c ${fakeroot-install-script}
      '';
      tarballName = mkDefault "wsl-${config.home.username}-${config.home.wsl.baseDistro}.tar.gz";
    };
  };
}
