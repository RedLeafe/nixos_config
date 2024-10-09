{ moduleNamespace, inputs, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
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
    # you can do autobuilt.pluginname.overrideAttrs to override them
    # and put the new replacement here.
  };
in
{
  options = {
    ${moduleNamespace}.WP = with lib; {
      enable = mkEnableOption "WordPress stuff";
      siteName = mkOption {
        default = "LunarLooters";
        type = types.str;
      };
      siteTLDs = mkOption {
        default = "com";
        type = types.str;
      };
    };
  };

  config = lib.mkIf cfg.enable {
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
    services.wordpress.sites.${cfg.siteName} = {
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
          # {
          #   ip = "*";
          #   port = 443;
          #   ssl = true;
          # }
        ];
        # sslServerCert = "/.${cfg.siteName}/${cfg.siteName}.crt"; # <-- wwwrun needs to be able to read it
        # sslServerKey = "/.${cfg.siteName}/${cfg.siteName}.key"; # <-- wwwrun needs to be able to read it
      };
      themes = {
        inherit (myWPext) vertice;
      };
      plugins = {
        inherit (myWPext)
          kubio
          ldap-login-for-intranet-sites
          any-hostname
          ;
        inherit (pkgs.wordpressPackages.plugins)
          wordpress-seo
          static-mail-sender-configurator
          ;
      };
      # https://developer.wordpress.org/apis/wp-config-php
      settings = {
        WP_DEFAULT_THEME = "vertice";
        WP_MAIL_FROM = "noreply@${lib.toLower cfg.siteName}.${cfg.siteTLDs}";
        # FORCE_SSL_ADMIN = true;
      };
      # https://codex.wordpress.org/Editing_wp-config.php
      # This file writes to $out/share/wordpress/wp-config.php
      # ABSPATH is the directory where wp-config.php resides
      extraConfig = /*php*/'' /* <?php */
        if ( !defined('ABSPATH') )
          define('ABSPATH', dirname(__FILE__) . '/');
        /* $_SERVER['HTTPS']='on'; */
      '';
    };
    environment.systemPackages = [
      (pkgs.writeShellScriptBin "gen_${cfg.siteName}_cert" (let
        SN = cfg.siteName;
        webuser = config.services.${config.services.wordpress.webserver}.user;
      in ''
        mkdir -p "./.${SN}" && \
        ${pkgs.openssl}/bin/openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -nodes -out "./.${SN}/${SN}.crt" -keyout "./.${SN}/${SN}.key" && \
        sudo mv -f "./.${SN}" / && \
        sudo chmod 740 "/.${SN}" && \
        sudo chown -R ${webuser}:root "/.${SN}"
      ''))
    ];
  };
}
