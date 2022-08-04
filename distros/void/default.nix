{
  pkgs,
  config,
  lib,
  ...
}: let
  sources = pkgs.callPackage ./generated.nix {};
  runBwrap = command: ''
    ${pkgs.bubblewrap}/bin/bwrap \
      --bind $PWD / \
      --uid 0 \
      --gid 0 \
      -- ${command}
  '';
in
  pkgs.writeShellScript "prepare-void" ''
    tar -xvf ${sources.rootfs.src}

    # FIXME: useradd fails with bad permissions
    ${runBwrap "/usr/bin/chmod u+w -R /etc"}

    ${runBwrap "/usr/bin/useradd -m -N -g 100 -G wheel -d ${config.home.homeDirectory} ${config.home.username}"}
  ''
