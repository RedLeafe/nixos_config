{ moduleNamespace, ... }: # <- a function
# that returns a module
{ config, pkgs, self, inputs, lib, ... }: {
  _file = ./default.nix;
  imports = [];
  options = {
    ${moduleNamespace}.thunar = {
      enable = lib.mkEnableOption "thunar config";
      plugins = lib.mkOption {
        default = [];
        type = lib.types.listOf lib.types.package;
        description = lib.mdDoc "List of thunar plugins to install.";
        example = lib.literalExpression "with pkgs.xfce; [ thunar-archive-plugin thunar-volman ]";
      };
      enableCustomActions = lib.mkOption {
        default = true;
        type = lib.types.bool;
      };
    };
  };
  config = lib.mkIf config.${moduleNamespace}.thunar.enable (let
    cfg = config.${moduleNamespace}.thunar;
    package = pkgs.xfce.thunar.override { thunarPlugins = cfg.plugins; };
  in {
    home.packages = [ package ];
    home.file = {
      ".config/Thunar/uca.xml".text = lib.mkIf cfg.enableCustomActions (builtins.readFile ./uca.xml);
    };
  });
}
