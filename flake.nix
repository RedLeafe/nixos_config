{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";

    # disk config
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # Literally just makes the terminal fullscreen
    maximizer.url = "github:BirdeeHub/maximizer";
    maximizer.inputs.nixpkgs.follows = "nixpkgs";

    # wordpress plugins
    # name them WPplugins-<plugin-name>
    # and a util grabs them and turns them into plugins
    # in the WP module
    WPplugins-ldap-login-for-intranet-sites = {
      url = "https://downloads.wordpress.org/plugin/ldap-login-for-intranet-sites.5.1.5.zip";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, disko, ... }@inputs: let
    stateVersion = "24.05";
    common = import ./common { inherit inputs; };
    inherit (common { overlaysList = true; }) overlays;
    inherit (common { nixos = true; }) system-modules;
    forAllSys = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all;
    username = "pluto";
    hostname = "nix";
  in
  {
    diskoConfigurations.${hostname} = import ./disko/sdaBIOS.nix;
    legacyPackages = forAllSys (system: {
      nixosConfigurations = {
        ${hostname} = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit stateVersion self inputs system-modules username hostname;
          };
          inherit system;
          modules = [
            disko.nixosModules.disko
            self.diskoConfigurations.${hostname}
            ./systems/vmware
            { nixpkgs.overlays = overlays; }
          ];
        };
        installer = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit self inputs system-modules stateVersion username hostname;
          };
          inherit system;
          modules = [
            { nixpkgs.overlays = overlays; }
            ./systems/installer
          ];
        };
      };
    });
  };
}
