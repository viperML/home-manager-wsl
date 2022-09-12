{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    home-manager = {
      url = "github:nix-community/home-manager/master";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };
  outputs = inputs @ {
    self,
    nixpkgs,
    home-manager,
  }: let
    inherit (nixpkgs) lib;
    genSystems = lib.genAttrs lib.systems.flakeExposed;
    hmConfig = baseDistro:
      home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
        modules = [
          (import ./home.nix inputs)
          self.homeModules.default
          {wsl.baseDistro = baseDistro;}
        ];
      };
  in {
    homeModules.default = import ./module.nix;
    homeConfigurations =
      {
        sample = self.homeConfigurations.sample-alpine;
      }
      // (lib.mapAttrs' (name: _: lib.nameValuePair "sample-${name}" (hmConfig name)) (builtins.readDir ./distros));
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
            (python3.withPackages (p: [p.black]))
            fakeroot
            htmlq
          ];
        };
    });
  };
}
