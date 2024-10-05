{ moduleNamespace, inputs, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.WP;
in {
  options = {
    ${moduleNamespace}.WP = with lib.types; {
      enable = lib.mkEnableOption "AD stuff";
    };
  };

  config = lib.mkIf cfg.enable (let
  in {
    services.wordpress.sites."LunarLooters" = {
      virtualHost = {
        listenAddresses = [ "0.0.0.0" ];
        hostName = "nix.alien.moon.mine";
      };
      database = {
        host = "localhost";
      };
      poolConfig = {
        "listen.owner" = "root";
        "listen.group" = "root";
      };
    };
  });
}
