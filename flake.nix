{
  inputs = {
    flake-parts = {
      url = "github:hercules-ci/flake-parts";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = {
    self,
    nixpkgs,
    flake-parts,
  }:
    flake-parts.lib.mkFlake {inherit self;} {
      systems = [
        "x86_64-linux"
      ];
      flake = {
        nixosConfigurations.host = nixpkgs.lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./configuration.nix
          ];
        };
      };
      perSystem = {pkgs, ...}: {
        packages = import ./default.nix {
          inherit pkgs nixpkgs;
          inherit (self.nixosConfigurations.host.config.system.build) toplevel;
        };
        devShells.default = pkgs.mkShell {
          packages = [
            pkgs.gnutar
            pkgs.file
          ];
        };
      };
    };
}
