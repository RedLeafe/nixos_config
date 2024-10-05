{
  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixpkgs-unstable";
    # home-manager = {
    #   url = "github:nix-community/home-manager";
    #   inputs.nixpkgs.follows = "nixpkgs";
    # };

    # disk config
    disko.url = "github:nix-community/disko";
    disko.inputs.nixpkgs.follows = "nixpkgs";

    # installer utility
    maximizer.url = "github:BirdeeHub/maximizer";
    maximizer.inputs.nixpkgs.follows = "nixpkgs";

    # neovim
    birdeeSystems.url = "github:BirdeeHub/birdeeSystems";
  };

  outputs = { self, nixpkgs, disko, ... }@inputs: let
    stateVersion = "24.05";
    common = import ./common { inherit inputs; };
    inherit (common { overlaysList = true; }) overlays;
    # inherit (common { homeManager = true; }) home-modules;
    inherit (common { nixos = true; }) system-modules;
    forAllSys = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all;
    username = "pluto";
    hostname = "nix";
  in
  {
    diskoConfigurations.${hostname} = import ./disko/sda_swap.nix;
    legacyPackages = forAllSys (system: {
      nixosConfigurations = {
        ${hostname} = nixpkgs.lib.nixosSystem {
          specialArgs = {
            inherit stateVersion self inputs system-modules username hostname;
            # inherit home-modules;
          };
          inherit system;
          modules = [
            disko.nixosModules.disko
            ./disko/sda_swap.nix
            ./systems/vmware
            ({ ... }:{
              nixpkgs.overlays = overlays;
            })
            # inputs.home-manager.nixosModules.home-manager
            # (
            #   { pkgs, lib, stateVersion, self, inputs, username, hostname, system-modules, ... }:
            #   {
            #     home-manager.useGlobalPkgs = true;
            #     home-manager.useUserPackages = true;
            #     home-manager.users.${username} = import ./homes/main-home.nix;
            #     home-manager.backupFileExtension = "hm-bkp";
            #     home-manager.verbose = true;
            #     home-manager.extraSpecialArgs = {
            #       inherit stateVersion self inputs hostname username home-modules;
            #     };
            #   }
            # )
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
