{ moduleNamespace, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.gitea;
in {
  options = {
    ${moduleNamespace}.gitea = with lib; {
      enable = mkEnableOption "gitea server";
      https = mkEnableOption "https support";
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
    };
  };
  config = lib.mkIf cfg.enable {
    services.gitea = {
      enable = true;
      lfs.enable = cfg.lfs;
      database = {
        port = cfg.dbport;
        type = cfg.dbtype;
      };
      settings = {
        server = {
          DOMAIN = cfg.domainname;
          ROOT_URL = "${if cfg.https then "https" else "http"}://${cfg.domainname}/";
          HTTP_PORT = if cfg.https then 443 else 80;
          COOKIE_SECURE = cfg.https;
          REDIRECT_OTHER_PORT = cfg.https;
          PORT_TO_REDIRECT = 80;
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
        proxyPass = "${if cfg.https then "https" else "http"}://127.0.0.1/";
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
  };
}
