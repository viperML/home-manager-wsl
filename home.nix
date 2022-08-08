inputs: {
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
      pkgs.nano
      (pkgs.callPackage ./bin/analyze_path.nix {})
    ];
    sessionVariables = {
      NIX_PATH = "nixpkgs=${config.xdg.configHome}/nix/nixpkgs";
    };
  };

  programs.home-manager.enable = true;

  xdg.configFile = {
    "home-manager-wsl/flake".source = ./.;
    "nix/nixpkgs".source = inputs.nixpkgs;
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
