{
  pkgs,
  config,
  ...
}: {
  home = {
    username = "sample";
    homeDirectory = "/home/${config.home.username}";
    stateVersion = "22.05";
    packages = [
      pkgs.nix
      pkgs.fish
    ];
  };
  programs.home-manager.enable = true;
  xdg.configFile = {
    "home-manager-wsl/test".text = ''
      Working!
    '';
    "home-manager-wsl/flake".source = ./.;
  };
  nix = {
    package = pkgs.nix;
    settings = {
      extra-experimental-features = [
        "nix-command"
        "flakes"
      ];
    };
  };
}
