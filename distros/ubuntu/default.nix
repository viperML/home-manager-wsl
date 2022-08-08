{
  pkgs,
  config,
  lib,
  ...
}: let
  sources = pkgs.callPackage ./generated.nix {};
in
  pkgs.writeShellScript "prepare-ubuntu" ''
    tar -xv -p -f ${sources.rootfs.src}

    ${lib.concatMapStringsSep "\n" (c: ''
        ${pkgs.bubblewrap}/bin/bwrap \
          --bind $PWD / \
          --uid 0 \
          --gid 0 \
          --setenv PATH /bin:/sbin:/usr/bin:/usr/sbin \
          -- ${c}
      '') [
        "useradd -m -N -g 100 -d ${config.home.homeDirectory} ${config.home.username}"
      ]}
  ''
