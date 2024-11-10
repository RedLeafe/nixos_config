{ moduleNamespace, inputs, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.bincache;
in {
  options = {
    ${moduleNamespace}.bincache = with lib; {
      enable = mkEnableOption "binary cache stuff";
      https = mkEnableOption "https support";
      domainname = mkOption {
        default = "localhost";
        type = types.str;
        description = "CANNOT CONTAIN A ':' CHARACTER";
      };
      location = mkOption {
        default = "/";
        type = types.str;
      };
    };
  };

  config = lib.mkIf cfg.enable {

    services.nix-serve = {
      enable = true;
      secretKeyFile = "/var/cache-priv-key.pem";
      bindAddress = "127.0.0.1";
      port = 5000;
    };

    services.httpd.enable = true;
    services.httpd.virtualHosts.${cfg.domainname} = {
      serverAliases = [ "*" ];
      listen = [
        {
          ip = "*";
          port = 1337;
          ssl = cfg.https;
        }
      ];
      locations.${cfg.location} = {
        proxyPass = "http://${config.services.nix-serve.bindAddress}:${builtins.toString config.services.nix-serve.port}/";
      };
      sslServerCert = lib.mkIf cfg.https "/.${cfg.domainname}/${cfg.domainname}.crt"; # <-- wwwrun needs to be able to read it
      sslServerKey = lib.mkIf cfg.https "/.${cfg.domainname}/${cfg.domainname}.key"; # <-- wwwrun needs to be able to read it
    };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "gen_binary_cache_cert" ''
        cd /var
        sudo nix-store --generate-binary-cache-key ${cfg.domainname} cache-priv-key.pem cache-pub-key.pem
        sudo chown nix-serve cache-priv-key.pem
        sudo chmod 600 cache-priv-key.pem
        cat cache-pub-key.pem
      '')
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
