{
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
  closureInfo = pkgs.closureInfo {
    rootPaths = [
      config.home.path
      config.home.activationPackage
    ];
  };
in {
  options.home.wsl = {
    tarball = mkOption {
      internal = true;
      type = types.package;
      description = "Package containing the WSL tarball";
    };
    provisionScripts = mkOption {
      internal = true;
      type = types.listOf types.package;
      description = "Scripts to run when creating the tarball";
    };
    extraProvisionScripts = mkOption {
      type = types.listOf types.package;
      description = "Scripts to run when creating the tarball";
      default = [];
    };
    packages = mkOption {
      type = types.listOf types.package;
      description = "Extra packages to cover alpine's packages";
      default = with pkgs; [
        coreutils-full
        less
        gnutar
        curl
        ncurses
      ];
    };
  };

  config = {
    home.packages = config.home.wsl.packages;
    home.wsl = {
      tarball = pkgs.runCommand "tarball" {} ''
        ${concatMapStringsSep "\n" (p: lib.getExe p) config.home.wsl.provisionScripts}
        ${concatMapStringsSep "\n" (p: lib.getExe p) config.home.wsl.extraProvisionScripts}

        mkdir -p $out

        ${pkgs.fakeroot}/bin/fakeroot sh -c ${./install.sh}
      '';
      provisionScripts = [
        (pkgs.writeShellScriptBin "prepare-alpine" ''
          tar -xvf ${alpine-tarball}
          cp -av ${./etc}/* etc

          tee etc/wsl.conf <<EOF
          [user]
          default=${config.home.username}
          EOF

          ${lib.concatMapStringsSep "\n" (p: "${pkgs.apk-tools}/bin/apk add --root $PWD --allow-untrusted ${p}") extraAlpinePackages}

          ${runBwrap "/usr/sbin/adduser -h ${config.home.homeDirectory} -s /bin/sh -G users -D ${config.home.username}"}
          ${runBwrap "/usr/sbin/addgroup ${config.home.username} wheel"}
        '')
        (pkgs.writeShellScriptBin "prepare-store" ''
          set -eux
          export NIX_REMOTE=local?root=$PWD
          export USER=nobody

          ${pkgs.nix}/bin/nix-store --load-db <${closureInfo}/registration
        '')
        (pkgs.writeShellScriptBin "prepare-profile" ''
          set -eux
          export NIX_REMOTE=local?root=$PWD
          export USER=nobody

          mkdir -p nix/var/nix/{profiles,gcroots/profiles}

          while read -r file; do
            cp -a $file nix/store
          done < ${closureInfo}/store-paths

          mkdir -p nix/var/nix/profiles/per-user/${config.home.username}

          ${pkgs.nix}/bin/nix \
            --extra-experimental-features 'nix-command flakes' \
            profile install \
            --profile nix/var/nix/profiles/per-user/${config.home.username}/profile \
            --offline \
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
        (pkgs.writeShellScriptBin "prepare-cleanup" ''
          rm -rvf nix/var/nix/profiles/per-user/nixbld
          rm -rf nix-*
          rm -fv env-vars
          rm -rf nix/var/nix/gcroots/auto/*
        '')
      ];
    };
  };
}
