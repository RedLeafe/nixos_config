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
  # myWPext contains built versions of flake inputs
  # matching WPplugins-<pluginname>
  # in a set myWPext.<pluginname>
  myWPext =
    let
      newpkgs = import inputs.nixpkgs {
        inherit (pkgs) system;
        overlays = [ ((import ./utils.nix).mkplugs inputs) ];
      };
    in
    newpkgs.myWPext;
in
{
  options = {
    ${moduleNamespace}.WP = with lib.types; {
      enable = lib.mkEnableOption "WordPress stuff";
    };
  };

  config = lib.mkIf cfg.enable (
    let
      finalWPplugins = myWPext // {
        ldap-login-for-intranet-sites = myWPext.ldap-login-for-intranet-sites.overrideAttrs (
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
      services.wordpress.sites."LunarLooters" = {
        database = {
          host = "localhost";
        };
        themes = {
          inherit (finalWPplugins) vertice;
        };
        plugins = {
          inherit (finalWPplugins)
            kubio
            ldap-login-for-intranet-sites
            ;
          inherit (pkgs.wordpressPackages.plugins)
            wordpress-seo
            ;
        };
        virtualHost = {
          serverAliases = [ "*" ];
          listen = [
            {
              ip = "0.0.0.0";
              port = 80;
            }
            # {
            #   ip = "0.0.0.0";
            #   port = 443;
            #   ssl = true;
            # }
          ];
          # sslServerCert = "/home/pluto/.cert/MyCertificate.crt";
          # sslServerKey = "/home/pluto/.cert/MyKey.key";
        };
        settings = {
          WP_DEFAULT_THEME = "vertice";
          # FORCE_SSL_ADMIN = true;
        };
        # extraConfig = /*php*/''
        #   $_SERVER['HTTPS']='on';
        # '';
      };
      services.httpd.enablePHP = true;
      services.httpd.phpPackage = pkgs.php.withExtensions (
        exts:
        with exts;
        [
        ]
      );
      services.httpd.phpOptions = # ini
        '''';
      services.mysql.settings.mysqld = {
        bind-address = "0.0.0.0";
      };
    }
  );
}
