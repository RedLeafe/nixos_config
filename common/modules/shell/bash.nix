{ moduleNamespace, homeManager, ... }:
{config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.bash;
in {
  _file = ./bash.nix;
  options = {
    ${moduleNamespace}.bash.enable = lib.mkEnableOption "birdeeBash";
  };
  config = lib.mkIf cfg.enable (let
    fzfinit = pkgs.stdenv.mkDerivation {
      name = "fzfinit";
      builder = pkgs.writeText "builder.sh" /* bash */ ''
        source $stdenv/setup
        ${pkgs.fzf}/bin/fzf --bash > $out
      '';
    };
  in if homeManager then {
    programs.bash = {
      enableVteIntegration = true;
      initExtra = ''
        export STARSHIP_CONFIG='${./starship.toml}'
        eval "$(${pkgs.starship}/bin/starship init bash)"
        source ${fzfinit}
      '';
    };
  } else {
    programs.bash = {
      promptInit = ''
        export STARSHIP_CONFIG='${./starship.toml}'
        eval "$(${pkgs.starship}/bin/starship init bash)"
        source ${fzfinit}
      '';
    };
  });
}
