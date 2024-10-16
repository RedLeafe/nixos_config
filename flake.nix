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
    WPplugins-media-sync = {
      url = "https://downloads.wordpress.org/plugin/media-sync.1.4.6.zip";
      flake = false;
    };
    WPplugins-kubio = {
      url = "https://downloads.wordpress.org/plugin/kubio.2.3.3.zip";
      flake = false;
    };
    WPplugins-any-hostname = {
      url = "github:dessibelle/any-hostname";
      flake = false;
    };
    WPthemes-vertice = {
      url = "https://downloads.wordpress.org/theme/vertice.1.0.25.zip";
      flake = false;
    };
  };

  outputs = { self, nixpkgs, disko, ... }@inputs: let
    stateVersion = "24.05";
    common = import ./common { inherit inputs; } { overlaysList = true; nixos = true; keys = true; };
    inherit (common) overlays system-modules authorized_keys;
    forAllSys = nixpkgs.lib.genAttrs nixpkgs.lib.platforms.all;
  in {
    diskoConfigurations.nix = import ./disko/sdaBIOS.nix;
    diskoConfigurations.pandemonium = import ./disko/sdaBIOS.nix;
    legacyPackages = forAllSys (system: {
      nixosConfigurations = {
        nix = nixpkgs.lib.nixosSystem (let # <-- wordpress host
          username = "pluto";
          hostname = "nix";
        in {
          specialArgs = {
            inherit stateVersion inputs system-modules username hostname authorized_keys;
          };
          inherit system;
          modules = [
            disko.nixosModules.disko
            self.diskoConfigurations.${hostname}
            { nixpkgs.overlays = overlays; }
            ./systems/${hostname}
          ];
        });
        pandemonium = nixpkgs.lib.nixosSystem (let # <-- gitea host
          username = "dorsa";
          hostname = "pandemonium";
        in {
          specialArgs = {
            inherit stateVersion inputs system-modules username hostname authorized_keys;
          };
          inherit system;
          modules = [
            disko.nixosModules.disko
            self.diskoConfigurations.${hostname}
            { nixpkgs.overlays = overlays; }
            ./systems/${hostname}
          ];
        });
        installer = nixpkgs.lib.nixosSystem (let
          hostconfig = {
            nix = {
              admin = "pluto";
              copyConfig = false;
              postinstall = installuser: /*bash*/ ''
                hostname="$1" # <- could change at call time
                admin="$2" # <- could change at call time
                # we also get the rest of the args passed to the install script
                DUMPFILE="''${3:-/home/${installuser}/wp-dump.tar.gz}"
                [ -d "$DUMPFILE" ] && sudo cp -vL "$DUMPFILE" /mnt/home/$admin
              '';
            };
            pandemonium = {
              admin = "dorsa";
              copyConfig = false;
              postinstall = installuser: /*bash*/ ''
                hostname="$1"
                admin="$2"
                DUMPFILE="$3"
                [ -z "$DUMPFILE" ] && DUMPFILE="$(ls -1 /home/${installuser}/gitea-dump-*.zip | sort -t '-' -k3 -nr | head -n 1)"
                [ -d "$DUMPFILE" ] && sudo cp -vL "$DUMPFILE" /mnt/home/$admin
              '';
            };
          };
        in {
          specialArgs = {
            inherit stateVersion inputs system-modules hostconfig authorized_keys;
          };
          inherit system;
          modules = [
            { nixpkgs.overlays = overlays; }
            ./systems/installer
          ];
        });
      };
    });
  };
}
