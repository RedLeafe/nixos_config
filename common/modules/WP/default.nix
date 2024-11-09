{ moduleNamespace, inputs, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.WP;
  autoWP = let
    newpkgs = import inputs.nixpkgs {
      inherit (pkgs) system;
      overlays = [
        # turns inputs named WPplugins-<pluginname>
        # in a set pkgs.myWPext.<pluginname>
        ((import ./utils.nix).mkplugs inputs)
      ];
    };
    myWPthemes = newpkgs.myWPthemes // {
      # you can do themename.overrideAttrs to override them
      # and put the new replacement here.
      # or just add more from other sources
    };
    myWPext = newpkgs.myWPext // {
      # you can do pluginname.overrideAttrs to override them
      # and put the new replacement here.
      # or just add more from other sources
      inherit (pkgs.wordpressPackages.plugins)
        static-mail-sender-configurator;
    };
  in { inherit myWPext myWPthemes; };
in
{
  options = {
    ${moduleNamespace}.WP = with lib; {
      enable = mkEnableOption "WordPress stuff";
      https = mkEnableOption "https support";
      forcehttps = mkEnableOption "force https";
      siteName = mkOption {
        default = "localhost";
        type = types.str;
      };
      mailaddr = mkOption {
        default = "noreply@example.com";
        type = types.str;
      };
      backup = {
        dir = mkOption {
          default = null;
          type = types.nullOr types.str;
        };
        number = mkOption {
          default = 3;
          type = types.int;
        };
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
            port = if cfg.https then 443 else 80;
            ssl = cfg.https;
          }
        ] ++ (lib.optionals (cfg.https && ! cfg.forcehttps)
        [
          {
            ip = "*";
            port = 443;
            ssl = true;
          }
        ]);
        sslServerCert = lib.mkIf cfg.https "/.${cfg.siteName}/${cfg.siteName}.crt"; # <-- wwwrun needs to be able to read it
        sslServerKey = lib.mkIf cfg.https "/.${cfg.siteName}/${cfg.siteName}.key"; # <-- wwwrun needs to be able to read it
      };
      themes = autoWP.myWPthemes;
      plugins = autoWP.myWPext;
      # https://developer.wordpress.org/apis/wp-config-php
      settings = {
        WP_DEFAULT_THEME = "vertice";
        WP_MAIL_FROM = "${cfg.mailaddr}";
        FORCE_SSL_ADMIN = cfg.forcehttps;
      };
      # https://codex.wordpress.org/Editing_wp-config.php
      # This file writes to $out/share/wordpress/wp-config.php
      # ABSPATH is the directory where wp-config.php resides
      extraConfig = /*php*/'' /* <?php */
        if ( !defined('ABSPATH') )
          define('ABSPATH', dirname(__FILE__) . '/');
        ${if cfg.https then "$_SERVER['HTTPS']='on';" else ""}
      '';
    };

    systemd = let
      servicename = "backup_runner";
      sqldbpkg = config.services.mysql.package;
      wp_dp_name = config.services.wordpress.sites.${cfg.siteName}.database.name;
      wp_ups = config.services.wordpress.sites.${cfg.siteName}.uploadsDir;
      dumpDBall = pkgs.writeShellScript "${servicename}-dump" ''
        export PATH="${lib.makeBinPath (with pkgs; [ sqldbpkg coreutils gnutar gzip ])}:$PATH";
        OUTFILE="$1"
        umask 022
        TEMPDIR="$(mktemp -d)"
        cleanup() {
          rm -rf "$TEMPDIR"
        }
        trap cleanup EXIT
        mkdir -p "$(dirname "$OUTFILE")"
        mysqldump '${wp_dp_name}' > "$TEMPDIR/dump.sql"
        cp -r '${wp_ups}' "$TEMPDIR"
        tar -cvf "$OUTFILE" --directory="$TEMPDIR" . --use-compress-program="gzip -9"
      '';
      servicescript = pkgs.callPackage (import ./utils.nix).backup_rotator {
        SCRIPTNAME = "${servicename}-rotate";
        MOST_RECENT = "${cfg.backup.dir}/wp-dump.tar.gz";
        CACHEDIR = "${cfg.backup.dir}/backupcache";
        dumpAction = dumpDBall;
        max = cfg.backup.number;
      };
    in {
      services.${servicename} = {
        description = "Run ${servicename}";
        serviceConfig = {
          ExecStart = "${pkgs.bash}/bin/bash ${servicescript}";
        };
      };
      timers."${servicename}-timer" = {
        description = "Timer to run ${servicename} every hour";
        timerConfig = {
          OnCalendar = "hourly";
          Persistent = true;
          Unit = "${servicename}.service";
        };
        wantedBy = [ "timers.target" ];
      };
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
