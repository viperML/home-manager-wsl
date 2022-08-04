{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    home-manager,
  }: let
    genSystems = nixpkgs.lib.genAttrs nixpkgs.lib.systems.flakeExposed;
  in {
    homeModules.default = import ./module.nix;
    homeConfigurations.sample = home-manager.lib.homeManagerConfiguration {
      pkgs = nixpkgs.legacyPackages."x86_64-linux";
      modules = [
        ./home.nix
        self.homeModules.default
      ];
    };
    formatter = genSystems (system: nixpkgs.legacyPackages.${system}.alejandra);
    devShells = genSystems (system: {
      default = with nixpkgs.legacyPackages.${system};
        mkShellNoCC {
          packages = [
            nvfetcher
            yq
            shellcheck
            shfmt
            self.formatter.${system}
          ];
        };
    });
  };
}
