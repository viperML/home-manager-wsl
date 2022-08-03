{
  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
    home-manager = {
      url = "github:nix-community/home-manager";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    flake-parts,
    home-manager,
  }:
    flake-parts.lib.mkFlake {inherit self;} {
      systems = [
        "x86_64-linux"
      ];
      flake = {
        homeConfigurations.sample = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          modules = [
            ./home.nix
            self.homeModules.default
          ];
        };
        homeModules.default = import ./module.nix;
      };
      perSystem = {pkgs, ...}: {
        packages = import ./default.nix {
          inherit pkgs;
          inherit (self.homeConfigurations.sample) config;
        };
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.gnutar
            pkgs.file
            pkgs.apk-tools
            pkgs.less
          ];
        };
      };
    };
}
