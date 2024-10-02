{ pkgs, lib, self, modulesPath, inputs, stateVersion, hostname, system-modules, nixpkgs, ... }: let
in {
  imports = with system-modules; [
    "${modulesPath}/virtualisation/vmware-guest.nix"
    ../vm.nix
    ./hardware-configuration.nix
  ];
  virtualisation.vmware.guest.enable = true;

  # Bootloader.
  boot.loader.timeout = 3;
  boot.loader.grub.enable = true;

  # disko sets this for us and will throw if we set it
  # boot.loader.grub.device = [ "/dev/sda" ];

  /* if you needed to swap it to an efi partition
     you could try these:
    boot.loader.grub.efiSupport = true;
    boot.loader.grub.efiInstallAsRemovable = true;
    boot.loader.efi.canTouchEfiVariables = true;
  */
}
