{ moduleNamespace, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.gitea;
in {
  options = {
    ${moduleNamespace}.gitea = with lib; {
      enable = mkEnableOption "gitea server";
      https = mkEnableOption "https support";
      PAM_support = mkEnableOption "PAM support";
      port = mkOption {
        default = if cfg.https then 443 else 80;
        type = types.int;
      };
      domainname = mkOption {
        default = "localhost";
        type = types.str;
      };
      lfs = mkEnableOption "large file support";
      dbtype = mkOption {
        default = "sqlite3";
        type = types.str;
      };
      dbport = mkOption {
        default = 3303;
        type = types.int;
      };
      backup_limit = mkOption {
        default = 3;
        type = types.int;
      };
      default_theme = mkOption {
        default = "gitea-dark-protanopia-deuteranopia";
        type = types.str;
      };
    };
  };
  config = lib.mkIf cfg.enable {
    services.gitea = {
      enable = true;
      package = if cfg.PAM_support then pkgs.gitea.overrideAttrs (prev: {
        buildInputs = with pkgs; [ linux-pam ] ++ (lib.optionals (prev ? buildInputs) prev.buildInputs);
        nativeBuildInputs = with pkgs; [ linux-pam ] ++ (lib.optionals (prev ? nativeBuildInputs) prev.nativeBuildInputs);
        tags = [ "sqlite" "sqlite_unlock_notify" "pam" ];
        doCheck = false;
      }) else pkgs.gitea;
      lfs.enable = cfg.lfs;
      dump.enable = true;
      # dump.interval = "*:0/1";
      dump.interval = "hourly";
      database = {
        port = cfg.dbport;
        type = cfg.dbtype;
      };
      settings = {
        server = {
          DOMAIN = cfg.domainname;
          ROOT_URL = "http://${cfg.domainname}/";
          # HTTP_PORT = if cfg.https then 443 else 80;
          # PROTOCOL = if cfg.https then "https" else "http";
          COOKIE_SECURE = cfg.https;
          # REDIRECT_OTHER_PORT = cfg.https;
          # PORT_TO_REDIRECT = 80;
        };
        ui = {
          DEFAULT_THEME = cfg.default_theme;
        };
      };
    };
    services.httpd.enable = true;
    services.httpd.virtualHosts.${cfg.domainname} = {
      serverAliases = [ "*" ];
      listen = [
        {
          ip = "*";
          port = 80;
        }
      ] ++ (lib.optionals cfg.https
      [
        {
          ip = "*";
          port = 443;
          ssl = true;
        }
      ]);
      sslServerCert = lib.mkIf cfg.https "/.${cfg.domainname}/${cfg.domainname}.crt"; # <-- wwwrun needs to be able to read it
      sslServerKey = lib.mkIf cfg.https "/.${cfg.domainname}/${cfg.domainname}.key"; # <-- wwwrun needs to be able to read it
      locations."/" = {
        proxyPass = "http://127.0.0.1:3000/";
      };
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "gen_${cfg.domainname}_cert" (let
        DN = cfg.domainname;
        webuser = config.services.httpd.user;
      in ''
        mkdir -p "./.${DN}" && \
        ${pkgs.openssl}/bin/openssl req -new -newkey rsa:4096 -x509 -sha256 -days 365 -nodes -out "./.${DN}/${DN}.crt" -keyout "./.${DN}/${DN}.key" && \
        sudo mv -f "./.${DN}" / && \
        sudo chmod 740 "/.${DN}" && \
        sudo chown -R ${webuser}:root "/.${DN}"
      ''))
    ];

    systemd = let
      servicename = "clearOldDumps";
      servicescript = let
        scrfun = max: path: pkgs.writeShellScript "${servicename}-script" ''
          export PATH="${lib.makeBinPath (with pkgs; [ coreutils ])}:$PATH"
          [ ! -d "${path}" ] && { mkdir -p "${path}" && exit 0; }
          to_delete=$(($(ls -1 '${path}' | wc -l) - ${builtins.toString max}))
          [ "$to_delete" -gt 0 ] && {
            for file in $(ls -1 '${path}' | sort -t '-' -k3 -n | head -n $to_delete); do
              rm "${path}/$file"
            done
          } || exit 0
        '';
      in scrfun cfg.backup_limit "${config.services.gitea.dump.backupDir}";
    in {
      services.${servicename} = {
        description = "Run ${servicename}";
        serviceConfig = {
          ExecStart = "${pkgs.bash}/bin/bash ${servicescript}";
        };
      };
      timers."${servicename}-timer" = {
        description = "Timer to run ${servicename} every 2 hours";
        timerConfig = {
          OnCalendar = "0/2:00:00";
          Persistent = true;
          Unit = "${servicename}.service";
        };
        wantedBy = [ "timers.target" ];
      };
    };
  };
}
