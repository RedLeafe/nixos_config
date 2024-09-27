# nix.moon.mine

to build the installer, run `./scripts/isoInstaller`

create a VMWare box, with minimum 2gb memory, 2 cores, and 35gb disk space (disk space will be reduced later, for now its a dev box for making stuff)

for system type choose other linux 5 or 6+ 64bit

It requires `BIOS` boot.

run the installer iso in the vmware box

it will open a terminal.
Run the `SPACEOS` command in it.

At the end of the `SPACEOS` command,
it will ask you to set a password for root,
and then for the user.

Once it is done, run `reboot`.

Start it back up, log in,

`alt+enter` to open the terminal

first run `sudo chown -R pluto:users /home/pluto/nixos_config`
so that it is no longer owned by root

Then run `sudo adcli join -D <YOUR_AD_DOMAIN> -U <YOUR_AD_USERNAME>` and enter your password at the prompt.

`cd nixos_config` and check it out!

`alt+f2` for chromium, view other keybinds in the i3 config at common/modules/i3

when you add or remove files, be sure to run `git add` or nix wont reflect the changes.

To rebuild any changes from within your vm, navigate to the config and run `./scripts/build`

## Structure:

```
nixos_config
│
├── flake.nix <- the entry point of the repo, imports things, exports system and installer configurations
├── flake.lock
│
├── scripts <- build scripts
│   ├── build
│   └── isoInstaller
│
├── common <- flake imports this, passes the results to system and home manager configs
│   ├── default.nix <- in charge of exporting the contents of /common as an easy to use set
│   ├── modules
│   │   ├── AD
│   │   │   └── default.nix
│   │   ├── ... other modules
│   │   │
│   │   │
│   │   └── default.nix <- a hub for importing all the modules as a set
│   │
│   └── overlays
│       ├── default.nix <- a hub for importing all the overlays as a list for passing to pkgs
│       ├── tmux
│       │   ├── default.nix
│       │   ├── package.nix
│       │   └── tmux_conf_var.diff
│       └── ... other overlays
│
├── disko <- used for provisioning disks on first install, and configuring the nixos options to find them
│   ├── sda_swap.nix
│   └── ... other disko modules
│
│   # Below this point, are the configurations for
│   # the systems and home manager configs output by the flake
│   # They import the modules and overlays from the common directory.
│   # and set some options for them, as well as containing other
│   # misc system or user config that didnt make sense to abstract
│   # into their own modules.
│
├── homes <- the directory for home manager configurations
│   ├── main-home.nix <- the only one that exists rn
│   └── ... other home manager configs
│
└── systems
    ├── installer <- the full config for the installer image
    │   ├── default.nix
    │   ├── installation-device.nix
    │   └── minimal-graphical-base.nix
    │
    ├── vm.nix <- a common vm system config
    ├── vmware <- vmware specific entry point, flake calls this, and this calls vm.nix
    │   ├── default.nix <- other vmware config
    │   └── hardware-configuration.nix <- generated hardware config (nixos-generate-config --show-hardware-config --no-filesystems)
    └── ... other systems
```

- [flakes](https://nixos.wiki/wiki/Flakes)
- [modules](https://nixos.wiki/wiki/NixOS_modules)
- [overlays](https://nixos.wiki/wiki/Overlays)
- [language reference](https://nix.dev/manual/nix/2.18/language/)
- [nix packages search](https://search.nixos.org/packages)
- [nixos module options search](https://search.nixos.org/options)
- [home-manager module options search](https://mipmip.github.io/home-manager-option-search/)
- [nix command docs](https://nix.dev/manual/nix/2.22/command-ref/new-cli/nix)
- [builtins and lib docs](https://teu5us.github.io/nix-lib.html)
- [flake inputs docs](https://nix.dev/manual/nix/2.22/command-ref/new-cli/nix3-flake#flake-references)
- [nix-pills (walkthrough of derivations and stdenv)](https://nixos.org/guides/nix-pills/)
- [nix cookbook (misc tips and tricks)](https://nixos.wiki/wiki/Nix_Cookbook)
- [nixos manual](https://nixos.org/manual/nixpkgs/stable/)
- [overriding packages](https://ryantm.github.io/nixpkgs/using/overrides/)
