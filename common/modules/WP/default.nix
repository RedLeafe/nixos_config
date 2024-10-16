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
    };
    myWPext = newpkgs.myWPext // {
      # you can do pluginname.overrideAttrs to override them
      # and put the new replacement here.
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
      backupDir = mkOption {
        default = null;
        type = types.nullOr types.str;
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
      themes = autoWP.myWPthemes // {
      };
      plugins = autoWP.myWPext // {
        inherit (pkgs.wordpressPackages.plugins)
          static-mail-sender-configurator;
      };
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
      dumpDBall = pkgs.writeShellScript "dumpDBall" ''
        export PATH="${lib.makeBinPath (with pkgs; [ sqldbpkg coreutils gnutar gzip ])}:$PATH";
        OUTFILE="$1"
        umask 027
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
      servicescript = pkgs.writeShellScript "${servicename}-script" ''
        export PATH="${lib.makeBinPath (with pkgs; [ sqldbpkg coreutils ])}:$PATH";
        umask 027
        MOST_RECENT="${cfg.backupDir}/wp-dump.tar.gz"
        CACHEDIR="${cfg.backupDir}/backupcache"
        cleanup() {
          find '${cfg.backupDir}' -type f -exec chmod 600 {} \;
        }
        trap cleanup EXIT
        if [ -e "$MOST_RECENT" ]; then
          mkdir -p "$CACHEDIR"
          files=( $CACHEDIR/* )
          max=3 # NOTE: breaks at max=10
          for (( i=$((''${#files[@]}-1)); i>=0; i-- )); do
            file="''${files[$i]}"
            [ "$CACHEDIR/*" == "$file" ] && break
            number="''${file##*[!0-9]}"
            base="''${file%%[0-9]*}"
            if [[ -n "$number" ]]; then
              incremented_number=$((number + 1))
            else
              incremented_number=1
            fi
            new_path="$base$incremented_number"
            if [ $incremented_number -gt $max ]; then
              rm -rf "$file"
            else
              mv "$file" "$new_path"
            fi
          done
          mv $MOST_RECENT "$CACHEDIR/$(basename "$MOST_RECENT").1"
        fi
        ${dumpDBall} "$MOST_RECENT"
      '';
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
