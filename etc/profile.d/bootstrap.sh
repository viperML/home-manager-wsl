if [ -n "$HOME" ] && [ -n "$USER" ]; then
    export PATH="/nix/var/nix/profiles/bootstrap/bin:$PATH"
    export NIX_USER_CONF_FILES="/etc/nix.conf"
fi
