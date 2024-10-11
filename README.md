# pandemonium & nix @ moon.mine

Run the correct script installed to the local admin user to get the backup dumps on nix and pandemonium hosts.
Save the files to your machine and clone this config.

With those, you can restore either nix or pandemonium hosts from any state if you know what you are doing.

The entire configuration for both machines are here, along with their installer.

## Structure:

```
nixos_config
│
├── flake.nix <- the entry point of the repo, imports things, exports system and installer configurations
├── flake.lock
│
├── scripts <- build scripts
│   ├── build <- build <hostname> [up]
│   └── isoInstaller <- builds vmware installer iso
│
├── common <- flake imports this, passes the results to system config (and also home manager if we had it)
│   ├── default.nix <- in charge of exporting the contents of /common as an easy to use set
│   ├── auth_keys
│   │   ├── operations@wrccdc.org
│   │   └── ... other public keys, 1 per file
│   ├── modules
│   │   ├── AD
│   │   │   └── default.nix
│   │   ├── xtermwm
│   │   │   └── default.nix
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
│   ├── sdaBIOS.nix
│   └── ... other disko modules
│
│   # Below this point, are the configurations for
│   # the systems output by the flake
│   # They import the modules and overlays from the common directory.
│   # and set some options for them, as well as containing other
│   # misc system or user config that didnt make sense to abstract
│   # into their own modules.
│
└── systems
    ├── vm.nix <- a common AD-joined vm system config
    │
    ├── nix <- host specific entry point, flake calls this, and this calls vm.nix
    │   ├── default.nix <- host specific config settings here
    │   └── hardware-configuration.nix <- generated hardware config (nixos-generate-config --show-hardware-config --no-filesystems)
    ├── pandemonium <- host specific entry point, flake calls this, and this calls vm.nix
    │   ├── default.nix <- host specific config settings here
    │   └── hardware-configuration.nix <- generated hardware config (nixos-generate-config --show-hardware-config --no-filesystems)
    ├── installer <- the full config for the installer image for both machines
    │   ├── default.nix
    │   ├── installation-device.nix
    │   └── minimal-graphical-base.nix
    └── ... other systems
```

## Helpful references:
- [flakes](https://nixos.wiki/wiki/Flakes)
- [modules](https://nixos.wiki/wiki/NixOS_modules)
- [overlays](https://nixos.wiki/wiki/Overlays)
- [language reference](https://nix.dev/manual/nix/2.18/language/)
- [nix packages search](https://search.nixos.org/packages)
- [nixos module options search](https://search.nixos.org/options)
- [home-manager module options search](https://mipmip.github.io/home-manager-option-search/) <- not installed in this config anymore
- [nix command docs](https://nix.dev/manual/nix/2.22/command-ref/new-cli/nix)
- [builtins and lib docs](https://teu5us.github.io/nix-lib.html)
- [trivial builders](https://ryantm.github.io/nixpkgs/builders/trivial-builders/)
- [flake inputs docs](https://nix.dev/manual/nix/2.22/command-ref/new-cli/nix3-flake#flake-references)
- [nix-pills (walkthrough of derivations and stdenv)](https://nixos.org/guides/nix-pills/)
- [nix cookbook (misc tips and tricks)](https://nixos.wiki/wiki/Nix_Cookbook)
- [nixos manual](https://nixos.org/manual/nixpkgs/stable/)
- [overriding packages](https://ryantm.github.io/nixpkgs/using/overrides/)
- [nix secrets rubrik](https://nixos.wiki/wiki/Comparison_of_secret_managing_schemes)
