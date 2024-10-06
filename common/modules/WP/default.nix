{ moduleNamespace, inputs, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.WP;
  myWPext = let
    # grabs inputs matching WPplugins-pluginname and puts them in pkgs.myWPext.pluginname
    newpkgs = import inputs.nixpkgs { inherit (pkgs) system; overlays = [ ((import ./utils.nix).mkplugs inputs) ]; };
  in newpkgs.myWPext;
in {
  options = {
    ${moduleNamespace}.WP = with lib.types; {
      enable = lib.mkEnableOption "WordPress stuff";
    };
  };

  config = lib.mkIf cfg.enable (let
    # TODO: figure out what to do with this.
    # likely override the path to it into ldap-login-for-intranet-sites plugin somewhere
    cfg_for_wp_ldap = ./miniorange-ldap-config.json;
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
        inherit (myWPext) ldap-login-for-intranet-sites;
      };
    };
    services.mysql.settings.mysqld = {
      bind-address = "0.0.0.0";
    };
  });
}
