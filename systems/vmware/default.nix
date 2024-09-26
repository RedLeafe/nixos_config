{ pkgs, lib, self, modulesPath, inputs, stateVersion, hostname, system-modules, nixpkgs, ... }: let
in {
  imports = with system-modules; [
    "${modulesPath}/virtualisation/vmware-guest.nix"
    ../vm.nix
    ./hardware-configuration.nix
  ];
  virtualisation.vmware.guest.enable = true;
}
