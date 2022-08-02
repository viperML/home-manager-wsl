{
  config,
  pkgs,
  modulesPath,
  lib,
  ...
}: {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];
  environment = {
    defaultPackages = [];
    systemPackages = [
      pkgs.nixos-install-tools
      pkgs.bubblewrap
    ];
    etc = {
    };
  };
  boot.isContainer = true;
  system.stateVersion = "22.11";
  system.activationScripts.binsh = lib.mkForce "";

  users.users.ayats = {
    password = "ayats";
    isNormalUser = true;
    createHome = true;
  };
}
