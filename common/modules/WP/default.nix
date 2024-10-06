{ moduleNamespace, inputs, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.WP;
  # contains built versions of flake inputs matching WPplugins-pluginname
  myWPext = let
    newpkgs = import inputs.nixpkgs { inherit (pkgs) system; overlays = [ ((import ./utils.nix).mkplugs inputs) ]; };
  in newpkgs.myWPext;
in {
  options = {
    ${moduleNamespace}.WP = with lib.types; {
      enable = lib.mkEnableOption "WordPress stuff";
    };
  };

  config = lib.mkIf cfg.enable (let
    ldap-login-for-intranet-sites = myWPext.ldap-login-for-intranet-sites.overrideAttrs (prev: let
      # TODO: figure out what to do with this.
      cfg_ldap = ./miniorange-ldap-config.json;
    in {
      # TODO: do something with cfg_ldap
      # instead of just overriding installPhase
      # with the same exact string it already had
      installPhase = "mkdir -p $out; cp -R * $out/";
    });
  in {
    services.wordpress.sites."LunarLooters" = {
      virtualHost = {
        listenAddresses = [ "0.0.0.0" ];
        serverAliases = [ "*" ];
      };
      database = {
        host = "localhost";
      };
      plugins = {
        inherit ldap-login-for-intranet-sites;
      };
    };
    services.mysql.settings.mysqld = {
      bind-address = "0.0.0.0";
    };
  });
}
