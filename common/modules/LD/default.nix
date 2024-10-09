{ moduleNamespace, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.LD;
in {
  _file = ./default.nix;
  options = {
    ${moduleNamespace}.LD = with lib.types; {
      enable = lib.mkEnableOption "LD stuff";
      extralibs = lib.mkOption {
        default = [];
        type = types.listOf types.package;
      };
    };
  };
  config = lib.mkIf cfg.enable (let
  in {
    programs.nix-ld = {
      enable  = true;
      package = pkgs.nix-ld;
      libraries = with pkgs; [
        # Add any missing global dynamic libraries for unpackaged programs here,
        # NOT in environment.systemPackages.
        # for use when wrapping the program with nix is infeasible
      ] ++ cfg.extralibs;
    };
  });
}
