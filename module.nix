{
  config,
  lib,
  pkgs,
  ...
}:
with lib; {
  options.wsl = {
    tarball = mkOption {
      internal = true;
      type = types.package;
      description = "Package containing the WSL tarball";
      readOnly = true;
      visible = true;
    };

    compressTarball = mkOption {
      type = types.bool;
      description = "Compress the result tarball";
      default = true;
    };

    baseTarball = mkOption {
      type = types.package;
      readOnly = true;
      visible = false;
    };

    extraProvisionCommands = mkOption {
      type = with types; listOf str;
      description = "Extra commands to run to create the tarball";
      default = [];
    };

    packages = mkOption {
      type = with types; listOf package;
      description = "Extra packages to provide a base environment";
      default = with pkgs; [
        wslu

        # Based on:
        # https://github.com/NixOS/nixpkgs/blob/nixos-unstable/nixos/modules/config/system-path.nix#L10
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
      description = "Linux distribution to use as a base, name of the folder in <repo root>/distros";
      default = "alpine";
    };

    conf = mkOption {
      type = with types; attrsOf (attrsOf (oneOf [string int bool]));
      description = "Configuration to write to /etc/wsl.conf";
    };
  };

  config = {
    home.packages =
      config.wsl.packages
      ++ [
        (pkgs.runCommandLocal "wsl-conf" {} ''
          mkdir -p $out/etc
          tee $out/etc/wsl.conf <<EOF
          # This file was written by home-manager-wsl at build time
          ${generators.toINI {} config.wsl.conf}
          EOF
        '')
        (pkgs.runCommandLocal "xdg-runtime-dir" {} ''
          install -Dm444 ${./bin/xdg-runtime-dir.sh} $out/etc/profile.d/xdg-runtime-dir.sh
        '')
      ];

    home.sessionVariables.BROWSER = "wslview";

    xdg = {
      enable = mkDefault true;
    };

    wsl = {
      conf = {
        user.default = config.home.username;
        automount.mountFsTab = true;
      };

      baseTarball = pkgs.callPackage ./distros/${config.wsl.baseDistro} {inherit config;};

      tarball = let
        closureInfo = pkgs.closureInfo {
          rootPaths = [
            config.home.path
            config.home.activationPackage
          ];
        };
        linkFromProfile = [
          "etc/profile.d/nix.sh"
          "etc/profile.d/hm-session-vars.sh"
          "etc/profile.d/xdg-runtime-dir.sh"
        ];
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

        outFile =
          "$out/wsl-tarball.tar"
          + (
            if config.wsl.compressTarball
            then ".gz"
            else ""
          );
      in
        pkgs.runCommand "home-manager-wsl-tarball" {
          nativeBuildInputs = [
            pkgs.nix
          ];
        } ''
          trap "set +x" ERR
          set -eux

          mkdir -p etc/profile.d
          mkdir -p $PWD${config.home.homeDirectory}

          ln -s /nix/var/nix/profiles/per-user/${config.home.username}/profile/etc/wsl.conf etc/wsl.conf

          tee etc/fstab <<EOF
          # This file was written by home-manager-wsl at build time
          tmpfs /tmp tmpfs mode=1777,nosuid,nodev,noatime 0 0
          EOF

          # Populate nix store
          export NIX_REMOTE=local?root=$PWD
          export USER=nobody
          nix-store --load-db <${closureInfo}/registration
          mkdir -p nix/var/nix/{profiles,gcroots/profiles}
          set +x
          echo "Copying nix store"
          while read -r file; do
            cp -a $file nix/store
          done < ${closureInfo}/store-paths
          set -x

          # Install and symlink profile
          mkdir -p nix/var/nix/profiles/per-user/${config.home.username}
          nix-env \
            --install \
            --prebuilt-only \
            --profile nix/var/nix/profiles/per-user/${config.home.username}/profile \
            ${config.home.path}
          ln -s /nix/var/nix/profiles/per-user/${config.home.username}/profile .${config.home.homeDirectory}/.nix-profile
          ln -s ${config.home.activationPackage} nix/var/nix/profiles/per-user/${config.home.username}/home-manager-1-link
          ln -s home-manager-1-link nix/var/nix/profiles/per-user/${config.home.username}/home-manager

          ${lib.concatMapStringsSep "\n" (file: "ln -sf /nix/var/nix/profiles/per-user/${config.home.username}/profile/${file} ${file}") linkFromProfile}

          # Run a home-manager activation
          export VERBOSE=1
          export HOME=$PWD${config.home.homeDirectory}
          export USER=${config.home.username}
          newGenFiles="$(readlink -e "${config.home.activationPackage}/home-files")"
          find "$newGenFiles" \( -type f -or -type l \) \
            -exec bash ${link} "$newGenFiles" {} +

          rm -rvf nix/var/nix/profiles/per-user/nixbld
          rm -rf nix-*
          rm -fv env-vars
          rm -rf nix/var/nix/gcroots/auto/*


          ${concatStringsSep "\n" config.wsl.extraProvisionCommands}

          cp -v ${config.wsl.baseTarball} result.tar
          chmod +w result.tar

          set +x
          echo "Appending files to the base distro"
          tar \
                --mtime='@1' \
                --hard-dereference \
                --sort=name \
                --numeric-owner \
                --owner=1000 \
                --group=100 \
                -rf result.tar ./nix .${config.home.homeDirectory}
          set -x

          tar \
                --mtime='@1' \
                --hard-dereference \
                --sort=name \
                --numeric-owner \
                --owner=0 \
                --group=0 \
                -rf result.tar ./etc

          mkdir -p $out
          ${
            if config.wsl.compressTarball
            then ''
              set +x
              echo "Compressing tarball"
              gzip -c result.tar > ${outFile}
            ''
            else "cp -v result.tar ${outFile}"
          }

          set +x
        '';
    };
  };
}
