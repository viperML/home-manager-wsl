{
  config,
  pkgs,
  modulesPath,
  ...
}: {
  imports = [
    "${modulesPath}/profiles/minimal.nix"
  ];
  environment = {
    defaultPackages = [];
    systemPackages = [
      pkgs.nixos-install-tools
      pkgs.bwrap
    ];
  };
  boot.isContainer = true;
  system.stateVersion = "22.11";
}
