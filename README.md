# ❄ home-manager-wsl

[Home-manager](https://github.com/nix-community/home-manager) module, that lets you build a [WSL](https://docs.microsoft.com/en-us/windows/wsl/about) distribution tarball, which contains:

- Alpine Linux as a base image
- Nix single-user installation
- Your HM config pre-installed and ready to go 🚀

Home-manager is a project that lets you build reproducible user environments using the [Nix package manager](https://nixos.org/).

## ✏️ Installation

The installation is as simple as possible. You will need a flake-based home-manager config.

1. Import the module into your config
    ```nix
    {
      inputs = {
        # ...
        home-manager-wsl.url = "github:viperML/home-manager-wsl";
      };
      outputs = {
        # ...
        home-manager-wsl,
      }: {
        homeConfigurations."USERNAME" = home-manager.lib.homeManagerConfiguration {
          modules = [
            # ...
            home-manager-wsl.homeModules.default
          ];
        };
      };
    }
    ```

2. Build the tarball

    ```console
    nix build /path/to/your/flake#homeConfigurations.USERNAME.config.home.wsl.tarball
    ```

3. Install

    Copy the resulting tarball under `./result/<name>.tar.gz` into your Windows Host with WSL2 enabled.

    Then, import it with `wsl --import <Distro> <InstallLocation> <PathToTarball>`


## 💨 Quick start

If you want to give it a spin without setting up a new flake, you can build the sample config of this repo.

```console
nix build github:viperML/home-manager-wsl#homeConfigurations.sample.config.home.wsl.tarball
```

And follow the installation guide from step 3.


## ⚙️ Configuration

> TODO

## 📐 Design considerations

### NixOS-WSL already exists

The project [NixOS-WSL](https://github.com/nix-community/NixOS-WSL) already provides a fully NixOS based WSL image. It is fantastic, but the main problem that I had with it is that it runs `systemd`. This brings some problems, because now any commands run from windows with the form `wsl.exe -d NixOS ls ~` will be run under the root user. In my experience, not running systemd means faster boot times.

Moreover, using an FHS distro with a runtime dynamic linker, simplifies the integration with the WSL ecosystem, where many tools will download dynamically-linked binaries (VSCode for example).


### Alpine Linux as a base

By using Alpine instead of something like Ubuntu, we get a cleaner `PATH` environment, without pre-installed tools like `gcc`, `python` or `make`. This makes the development experience closer to what developing in NixOS is.

Letting the user use any other distro is in the TODO list though.

## 📄 Disclaimer

This project is not directly affiliated with home-manager.
