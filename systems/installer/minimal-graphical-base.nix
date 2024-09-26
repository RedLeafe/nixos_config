# This module contains the basic configuration for building a graphical NixOS
# installation CD.
{ config, lib, pkgs, modulesPath, ... }:
{
  imports = [
    "${modulesPath}/installer/cd-dvd/iso-image.nix"
    ./installation-device.nix
  ];
  # Whitelist wheel users to do anything
  # This is useful for things like pkexec
  #
  # WARNING: this is dangerous for systems
  # outside the installation-cd and shouldn't
  # be used anywhere else.
  security.polkit.extraConfig = ''
    polkit.addRule(function(action, subject) {
      if (subject.isInGroup("wheel")) {
        return polkit.Result.YES;
      }
    });
  '';
  # Provide networkmanager for easy wireless configuration.
  networking.networkmanager.enable = true;
  networking.wireless.enable = lib.mkImageMediaOverride false;

  # KDE complains if power management is disabled (to be precise, if
  # there is no power management backend such as upower).
  # powerManagement.enable = true;

  # VM guest additions to improve host-guest interaction
  # services.spice-vdagentd.enable = true;
  # services.qemuGuest.enable = true;
  # virtualisation.vmware.guest.enable = pkgs.stdenv.hostPlatform.isx86;
  virtualisation.vmware.guest.enable = true;
  # virtualisation.hypervGuest.enable = true;
  # services.xe-guest-utilities.enable = pkgs.stdenv.hostPlatform.isx86;
  # The VirtualBox guest additions rely on an out-of-tree kernel module
  # which lags behind kernel releases, potentially causing broken builds.
  virtualisation.virtualbox.guest.enable = false;

  # Include support for various filesystems and tools to create / manipulate them.
  boot.supportedFilesystems =
    [ "btrfs" "cifs" "f2fs" "ntfs" "vfat" "xfs" ] ++
    lib.optional (lib.meta.availableOn pkgs.stdenv.hostPlatform config.boot.zfs.package) "zfs";

  # Configure host id for ZFS to work
  networking.hostId = lib.mkDefault "8425e349";

  # boot.plymouth.enable = true;
  environment.defaultPackages = with pkgs; [
    mesa-demos
    open-vm-tools-headless
    testdisk # useful for repairing boot problems
    ms-sys # for writing Microsoft boot sectors / MBRs
    efibootmgr
    efivar
    parted
    gptfdisk
    ddrescue
    ccrypt
    cryptsetup # needed for dm-crypt volumes
    # Some networking tools.
    fuse
    fuse3
    sshfs-fuse
    socat
    screen
    tcpdump

    # Hardware-related tools.
    sdparm
    hdparm
    smartmontools # for diagnosing hard disks
    pciutils
    usbutils
    nvme-cli

    # Some compression/archiver tools.
    unzip
    zip
  ];

}
