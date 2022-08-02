{pkgs, ...}: {
  home = {
    username = "ayats";
    homeDirectory = "/home/ayats";
    stateVersion = "22.11";
    packages = [
      pkgs.nix
      pkgs.coreutils-full
      pkgs.less

      pkgs.fish
    ];
  };
}
