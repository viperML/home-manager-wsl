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
  pkgs.writeShellScript "prepare-alpine" ''
    tar -xvf ${sources.rootfs.src}
    cp -av ${./etc}/* etc

    ${runBwrap "/usr/sbin/adduser -h ${config.home.homeDirectory} -s /bin/sh -G users -D ${config.home.username}"}
    ${runBwrap "/usr/sbin/addgroup ${config.home.username} wheel"}
  ''
