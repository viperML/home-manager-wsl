{
  pkgs,
  config,
}: let
  inherit (pkgs) lib;

  closureInfo = pkgs.closureInfo {
    rootPaths = [
      config.home.path
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

      ${runBwrap "/usr/sbin/adduser -h ${config.home.homeDirectory} -s /bin/sh -G users -D ${config.home.username}"}
      ${runBwrap "/usr/sbin/addgroup ${config.home.username} wheel"}
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

      while read -r file; do
        cp -av $file nix/store
      done < ${closureInfo}/store-paths

      mkdir -p nix/var/nix/profiles/per-user/${config.home.username}

      ${pkgs.nix}/bin/nix \
        --extra-experimental-features 'nix-command flakes' \
        profile install \
        --profile nix/var/nix/profiles/per-user/${config.home.username}/profile \
        --offline \
        ${config.home.path}

      ln -s /nix/var/nix/profiles/per-user/${config.home.username}/profile .${config.home.homeDirectory}/.nix-profile

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
    '';
    cleanup = pkgs.writeShellScriptBin "prepare-cleanup" ''
      rm -rvf nix/var/nix/profiles/per-user/nixbld
      rm -rf nix-*
      rm -fv env-vars
    '';
  };

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

  tarball = pkgs.runCommand "tarball" {} ''
    ${lib.getExe prepare.alpine}
    ${lib.getExe prepare.store}
    ${lib.getExe prepare.profile}
    ${lib.getExe prepare.cleanup}

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
