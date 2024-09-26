{ moduleNamespace, homeManager, ... }: # <- a function
# that returns a module
{config, pkgs, self, inputs, lib, ... }: let

  alakitty-toml = { zsh, ... }: let
  in (/*toml*/''
    # https://alacritty.org/config-alacritty.html
    # [env]
    # TERM = "xterm-256color"

    [shell]
    program = "${zsh}/bin/zsh"
    args = [ "-l" ]

    [font]
    size = 11.0

    [font.bold]
    family = "FiraMono Nerd Font"
    style = "Bold"

    [font.bold_italic]
    family = "FiraMono Nerd Font"
    style = "Bold Italic"

    [font.italic]
    family = "FiraMono Nerd Font"
    style = "Italic"

    [font.normal]
    family = "FiraMono Nerd Font"
    style = "Regular"
  '');

in {
  _file = ./default.nix;
  options = {
    ${moduleNamespace}.alacritty = with lib.types; {
      enable = lib.mkEnableOption "alacritty";
      extraToml = lib.mkOption {
        default = "";
        type = str;
      };
    };
  };
  config = lib.mkIf config.${moduleNamespace}.alacritty.enable (let
    cfg = config.${moduleNamespace}.alacritty;
    final-alakitty-toml = pkgs.writeText "alacritty.toml" (builtins.concatStringsSep "\n" [
      (pkgs.callPackage alakitty-toml { inherit homeManager inputs; })
      cfg.extraToml
      ]);
    alakitty = pkgs.writeShellScriptBin "alacritty" ''
      exec ${pkgs.alacritty}/bin/alacritty --config-file ${final-alakitty-toml} "$@"
    '';
  in (if homeManager then {
    home.packages = [ alakitty ];
  } else {
    environment.systemPackages = [ alakitty ];
  }));
}
