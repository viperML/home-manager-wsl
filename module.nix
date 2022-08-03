{
  config,
  lib,
  pkgs,
  ...
}:
with lib; let
  results = import ./default.nix {
    inherit config pkgs;
  };
in {
  options.home.wsl = {
    tarball = mkOption {
      internal = true;
      type = types.package;
      description = "Package containing the WSL tarball";
    };
  };

  config = {
    home.wsl = {
      tarball = results.tarball;
    };
  };
}
