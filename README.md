# nix.moon.mine

## Build the installer:

to build the installer, clone the repo, navigate to it, and run `./scripts/isoInstaller`

This will build a vmware specific installer iso.

Make a machine and boot from the iso.

## Machine requirements:

IT REQUIRES BIOS BOOT. Give it about 16 GB disk size

You could get away with 2 cores 2-3gb ram for initial build. If it freezes you can shut it down and run SPACEOS-install to pick up more or less where it left off when its back up

I just make it 4 core and 4 GB and it builds in a sane amount of time with 0 risk of freezing. Its not worth waiting longer when you dont need to.

There is a way to do the install and building on a separate machine to get around this issue. I didnt do it for this box.

Reduce it to 1 core 2gb ram after.

This should handle running nixos-rebuild while still keeping the services running after the machine has been built the first time.

## Running the installer:

When you boot into the installer, you can log in with no password.

You will see a terminal. Run the `SPACEOS` command in it.

At the end of the `SPACEOS` command, it will ask you to set a password for root, and then for the user.

Once it is done, run reboot.

Start it back up, log in as pluto.

first run `ssh-keygen` to get some keys so you can ssh in as the pluto user

then run `sudo chown -R pluto:users /home/pluto/nixos_config` so that it is no longer owned by root

Then run `sudo net ads join -U Administrator` and enter your password at the prompt.

Afterwards, reboot the machine again.

Log into wordpress, log into AD in wordpress ldap plugin, and import the page stuff, I havent figured this out yet

To rebuild any changes to the nix config from within your vm, navigate to the config and run `./scripts/build`

when you add or remove files, be sure to run `git add` or nix wont reflect the changes. Although, currently the config provisioned by the installer isn't a git repo so this doesn't apply until it is one.

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
├── common <- flake imports this, passes the results to system config (and also home manager if we had it)
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
│   # the systems output by the flake
│   # They import the modules and overlays from the common directory.
│   # and set some options for them, as well as containing other
│   # misc system or user config that didnt make sense to abstract
│   # into their own modules.
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
- [home-manager module options search](https://mipmip.github.io/home-manager-option-search/) <- not installed in this config anymore
- [nix command docs](https://nix.dev/manual/nix/2.22/command-ref/new-cli/nix)
- [builtins and lib docs](https://teu5us.github.io/nix-lib.html)
- [flake inputs docs](https://nix.dev/manual/nix/2.22/command-ref/new-cli/nix3-flake#flake-references)
- [nix-pills (walkthrough of derivations and stdenv)](https://nixos.org/guides/nix-pills/)
- [nix cookbook (misc tips and tricks)](https://nixos.wiki/wiki/Nix_Cookbook)
- [nixos manual](https://nixos.org/manual/nixpkgs/stable/)
- [overriding packages](https://ryantm.github.io/nixpkgs/using/overrides/)
