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
    trap "set +x" ERR
    set -eux
    chown -R 1000:100 nix
    chown -R 1000:100 home/*

    rm -rf tmp
    mkdir -m 1777 tmp

    set +x
    echo "Creating tarball, don't panic if it looks stuck"
    tar \
        --sort=name \
        --mtime='@1' \
        --gzip \
        --numeric-owner \
        --hard-dereference \
        --ignore-failed-read \
        -c * > $out/${config.home.wsl.tarballName}
  '';
  xdg-runtime-dir = pkgs.runCommandLocal "xdg-runtime-dir" {} ''
    install -Dm444 ${./bin/xdg-runtime-dir.sh} $out/etc/profile.d/xdg-runtime-dir.sh
  '';
  wsl-conf = pkgs.runCommandLocal "wsl-conf" {} ''
    mkdir -p $out/etc
    tee $out/etc/wsl.conf <<EOF
    # This file was written by home-manager-wsl at build time
    ${generators.toINI {} config.home.wsl.conf}
    EOF
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
  };

  config = {
    home.packages =
      config.home.wsl.packages
      ++ [
        wsl-conf
        xdg-runtime-dir
      ];

    xdg = {
      enable = mkDefault true;
    };

    home.wsl = {
      conf = {
        user.default = config.home.username;
      };
      provisionScripts = [
        (import ./distros/${config.home.wsl.baseDistro} args)
        (pkgs.writeShellScript "prepare-wsl" ''
          ln -s /nix/var/nix/profiles/per-user/${config.home.username}/profile/etc/wsl.conf etc/wsl.conf

          tee etc/fstab <<EOF
          # This file was written by home-manager-wsl at build time
          tmpfs /tmp tmpfs mode=1777,nosuid,nodev,noatime 0 0
          EOF
        '')
        (pkgs.writeShellScript "prepare-store" ''
          export NIX_REMOTE=local?root=$PWD
          export USER=nobody

          ${pkgs.nix}/bin/nix-store --load-db <${closureInfo}/registration
        '')
        (pkgs.writeShellScript "prepare-profile" ''
          export NIX_REMOTE=local?root=$PWD
          export USER=nobody

          mkdir -p nix/var/nix/{profiles,gcroots/profiles}

          set +x
          echo "Copying nix store"
          while read -r file; do
            cp -a $file nix/store
          done < ${closureInfo}/store-paths
          set -x

          mkdir -p nix/var/nix/profiles/per-user/${config.home.username}

          ${pkgs.nix}/bin/nix-env \
            --install \
            --prebuilt-only \
            --profile nix/var/nix/profiles/per-user/${config.home.username}/profile \
            ${config.home.path}

          # TODO let the user add files to link

          ln -s /nix/var/nix/profiles/per-user/${config.home.username}/profile .${config.home.homeDirectory}/.nix-profile

          ln -s ${config.home.activationPackage} nix/var/nix/profiles/per-user/${config.home.username}/home-manager-1-link
          ln -s home-manager-1-link nix/var/nix/profiles/per-user/${config.home.username}/home-manager

          chmod +w etc/profile.d
          for file in nix.sh hm-session-vars.sh xdg-runtime-dir.sh; do
            ln -s \
              /nix/var/nix/profiles/per-user/${config.home.username}/profile/etc/profile.d/$file \
              etc/profile.d/$file
          done

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
        trap "set +x" ERR
        set -eux
        ${concatStringsSep "\n" config.home.wsl.provisionScripts}
        ${concatStringsSep "\n" config.home.wsl.extraProvisionScripts}

        mkdir -p $out
        ${pkgs.fakeroot}/bin/fakeroot sh -c ${fakeroot-install-script}
        set +x
      '';
      tarballName = mkDefault "wsl-${config.home.username}-${config.home.wsl.baseDistro}.tar.gz";
    };
  };
}
