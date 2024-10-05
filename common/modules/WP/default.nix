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
    ldap-plugin = pkgs.stdenv.mkDerivation rec {
      name = "ldap-login-for-intranet-sites";
      version = "5.1.5";
      src = pkgs.fetchzip {
        url = "https://downloads.wordpress.org/plugin/${name}.${version}.zip";
        hash = "sha256-uOYknoFWRXNH1GMz5lpMR6MRjCJP9Nm+MjVW8onmxew=";
      };
      installPhase = "mkdir -p $out; cp -R * $out/";
    };
  in {
    services.wordpress.sites."LunarLooters" = {
      virtualHost = {
        listenAddresses = [ "0.0.0.0" ];
        serverAliases = [ "*" ];
      };
      database = {
        host = "localhost";
      };
      plugins = [
        ldap-plugin
      ];
      # poolConfig = {
      #   "listen.owner" = "root";
      #   "listen.group" = "root";
      # };
    };
    services.mysql.settings.mysqld = {
      bind-address = "0.0.0.0";
    };
  });
}
