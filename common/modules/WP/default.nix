{ moduleNamespace, inputs, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.WP;
in {
  options = {
    ${moduleNamespace}.WP = with lib.types; {
      enable = lib.mkEnableOption "AD stuff";
    };
  };

  config = lib.mkIf cfg.enable (let
    # TODO: figure out what to do with this.
    cfg_for_wp_ldap = ./miniorange-ldap-config.json;

    ldap-login-for-intranet-sites = pkgs.stdenv.mkDerivation (let
      name = "ldap-login-for-intranet-sites";
      version = "5.1.5";
    in {
      inherit name version;
      src = pkgs.fetchzip {
        url = "https://downloads.wordpress.org/plugin/${name}.${version}.zip";
        hash = "sha256-uOYknoFWRXNH1GMz5lpMR6MRjCJP9Nm+MjVW8onmxew=";
      };
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
      # poolConfig = {
      # };
    };
    services.httpd.user = "root";
    services.httpd.group = "root";
    services.mysql.settings.mysqld = {
      bind-address = "0.0.0.0";
    };
  });
}
