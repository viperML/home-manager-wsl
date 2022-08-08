if [ -n "$HOME" ] && [ -n "$USER" ] && [ -z "$XDG_RUNTIME_DIR" ]; then
    # We can't use /run, only root has write access
    export XDG_RUNTIME_DIR="/tmp/user-$(id -u)-xdg-runtime"
    mkdir -p -m 700 "$XDG_RUNTIME_DIR"
fi
