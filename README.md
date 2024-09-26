to build the installer, run `./scripts/isoInstaller`

create a VMWare box, with minimum 2gb memory, 2 cores, and 50gb disk space (disk space will be reduced later, for now its a dev box for making stuff)

for system type choose other linux 6+ 64bit

run the installer iso in the vmware box

it will open a terminal.
Run the `SPACEOS` command in it.

At the end of the `SPACEOS` command,
it will ask you to set a password for root,
and then for the user.

Once it is done, shutdown the vm,
and remove the iso.

Start it back up, log in,

`alt+enter` to open the terminal

navigate to `~/nixos_config`

use `vim .` to check it out!

`alt+f2` for chromium

when you add or remove files, be sure to run `git add` or nix wont reflect the changes.

To rebuild any changes from within your vm, navigate to the config and run `./scripts/build`
