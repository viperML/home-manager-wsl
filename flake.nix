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
      perSystem = {pkgs, ...}: {
        packages = import ./default.nix {
          inherit pkgs;
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
