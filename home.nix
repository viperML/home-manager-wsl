{pkgs, ...}: {
  home = {
    username = "ayats";
    homeDirectory = "/home/ayats";
    stateVersion = "22.05";
    packages = [
      pkgs.nix
      pkgs.fish
    ];
  };
  xdg.configFile."home-manager-wsl-test".text = ''
    Working!
  '';
}
