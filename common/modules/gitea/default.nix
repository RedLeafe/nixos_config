{ moduleNamespace, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.gitea;
in {
  options = {
    ${moduleNamespace}.gitea = with lib; {
      enable = mkEnableOption "gitea server";
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
  config = lib.mkIf cfg.enable (let
  in {
    services.gitea = {
      enable = true;
      database = {
        port = cfg.dbport;
        type = cfg.dbtype;
      };
      settings.server.DOMAIN = "0.0.0.0";
    };
  });
}
