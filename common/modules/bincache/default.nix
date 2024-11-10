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
      bindAddress = "0.0.0.0";
      port = 1337;
    };

    # services.httpd.enable = true;
    # services.httpd.virtualHosts.${cfg.domainname} = {
    #   serverAliases = [ "*" ];
    #   listen = [
    #     {
    #       ip = "*";
    #       port = 1337;
    #     }
    #   ];
    #   locations.${cfg.location} = {
    #     proxyPass = "http://${config.services.nix-serve.bindAddress}:${builtins.toString config.services.nix-serve.port}/";
    #   };
    # };

    environment.systemPackages = [
      (pkgs.writeShellScriptBin "gen_binary_cache_cert" ''
        cd /var
        sudo nix-store --generate-binary-cache-key ${cfg.domainname} cache-priv-key.pem cache-pub-key.pem
        sudo chown nix-serve cache-priv-key.pem
        sudo chmod 600 cache-priv-key.pem
        cat cache-pub-key.pem
      '')
    ];
  };
}
