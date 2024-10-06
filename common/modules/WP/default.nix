{ moduleNamespace, inputs, ... }: # <- a function
# that returns a module
{
  config,
  pkgs,
  lib,
  ...
}:
let
  cfg = config.${moduleNamespace}.WP;
  myWPext = let
    autobuilt = let
      newpkgs = import inputs.nixpkgs {
        inherit (pkgs) system;
        overlays = [
          # turns inputs named WPplugins-<pluginname>
          # in a set pkgs.myWPext.<pluginname>
          ((import ./utils.nix).mkplugs inputs)
        ];
      };
    in newpkgs.myWPext;
  in autobuilt // {
    # a place to put overrides:
    ldap-login-for-intranet-sites = autobuilt.ldap-login-for-intranet-sites.overrideAttrs (
      prev:
      let
        # TODO: figure out what to do with this.
        cfg_ldap = ./miniorange-ldap-config.json;
      in
      {
        # TODO: do something with cfg_ldap
        # instead of just overriding installPhase
        # with the same exact string it already had
        # installPhase = "mkdir -p $out; cp -R * $out/";
      }
    );
  };
in
{
  options = {
    ${moduleNamespace}.WP = with lib.types; {
      enable = lib.mkEnableOption "WordPress stuff";
    };
  };

  config = lib.mkIf cfg.enable ({
      services.httpd.enablePHP = true;
      services.httpd.phpPackage = pkgs.php.withExtensions
        (exts: with exts; [
          # download php extensions from nixpkgs here from exts variable
        ]);
      # write to php.ini
      services.httpd.phpOptions = /*ini*/ ''
      '';
      services.mysql.settings.mysqld = {
        bind-address = "0.0.0.0";
      };
      services.wordpress.sites."LunarLooters" = {
        database = {
          host = "localhost";
        };
        virtualHost = {
          serverAliases = [ "*" ];
          listen = [
            {
              ip = "*";
              port = 80;
            }
            {
              ip = "*";
              port = 443;
              ssl = true;
            }
          ];
          sslServerCert = "/certs/MyCertificate.crt";
          sslServerKey = "/certs/MyKey.key";
        };
        themes = {
          inherit (myWPext) vertice;
        };
        plugins = {
          inherit (myWPext)
            kubio
            ldap-login-for-intranet-sites
            ;
          inherit (pkgs.wordpressPackages.plugins)
            wordpress-seo
            ;
        };
        # https://developer.wordpress.org/apis/wp-config-php
        settings = {
          WP_DEFAULT_THEME = "vertice";
          # FORCE_SSL_ADMIN = true;
        };
        # https://codex.wordpress.org/Editing_wp-config.php
        # This file writes to $out/share/wordpress/wp-config.php
        # ABSPATH is the directory where wp-config.php resides
        extraConfig = /*php*/'' /* <?php */
          if ( !defined('ABSPATH') )
            define('ABSPATH', dirname(__FILE__) . '/');
            require_once(ABSPATH . 'wp-admin/includes/plugin.php');
        '';
      };
    }
  );
}
