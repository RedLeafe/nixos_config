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
  });
}
