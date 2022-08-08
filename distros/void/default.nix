{
  pkgs,
  config,
  lib,
  ...
}: let
  sources = pkgs.callPackage ./generated.nix {};
in ''
  set +e
  tar -x -p -f ${sources.rootfs.src}
  set -e

  ${lib.concatMapStringsSep "\n" (c: ''
      ${pkgs.bubblewrap}/bin/bwrap \
        --bind $PWD / \
        --uid 0 \
        --gid 0 \
        --setenv PATH /bin:/sbin:/usr/bin:/usr/sbin \
        -- ${c}
    '') [
      # FIXME: useradd fails with bad permissions
      "chmod u+w -R /etc"
      "useradd -m -N -g 100 -G wheel -d ${config.home.homeDirectory} ${config.home.username}"
    ]}
  set +x
''
