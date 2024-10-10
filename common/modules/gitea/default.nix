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
      dump.enable = true;
      dump.interval = "*:0/1";
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
      };
      # extraConfig = '' <- AI slop these keys dont exist. some do exist in the UI tho so Im not gonna delete them
      #   [auth.ldap]
      #   name = LDAP
      #   type = ldap
      #   auth_source = 1
      #   enabled = true
      #   skip_verify = false
      #   host = kerberos.alien.moon.mine
      #   port = 389
      #   user_search_base = CN=Users,DC=alien,DC=moon,DC=mine
      #   # user_filter = (uid=%s) # For OpenLDAP
      #   user_filter = (sAMAccountName=%s) # For Active Directory
      #   admin_filter = (&(objectClass=group)(cn=admins))"
      #   attribute_username = sAMAccountName # Active Directory
      #   # attribute_username = uid # OpenLDAP
      #   attribute_name = cn
      #   attribute_surname = sn
      #   attribute_mail = mail
      #   search_page_size = 0
      #   bind_dn = CN=Administrator,CN=Users,DC=alien,DC=moon,DC=mine
      # '';
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
    environment.systemPackages = (let
      GETDUMP = pkgs.writeShellScriptBin "GET_GIT_DUMP" ''
        sudo systemctl restart gitea-dump.service
        cp "$(ls -1 '${config.services.gitea.dump.backupDir}' | sort -t '-' -k3 -nr | head -n 1)" .
      '';
    in [
      GETDUMP
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
    ]);
  };
}
