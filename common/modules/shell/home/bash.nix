{ moduleNamespace, ... }: # <- a function
# that returns a module
{config, pkgs, self, inputs, lib, ... }:
{
  _file = ./bash.nix;
  options = {
    ${moduleNamespace}.bash.enable = lib.mkEnableOption "Bash";
  };
  config = lib.mkIf config.${moduleNamespace}.bash.enable (let
    cfg = config.${moduleNamespace}.bash;
    fzfinit = pkgs.stdenv.mkDerivation {
      name = "fzfinit";
      builder = pkgs.writeText "builder.sh" /* bash */ ''
        source $stdenv/setup
        ${pkgs.fzf}/bin/fzf --bash > $out
      '';
    };
  in {
    programs.bash = {
      enableVteIntegration = true;
      initExtra = ''
        eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init bash --config ${../atomic-emodipt.omp.json})"
        source ${fzfinit}
      '';
    };
  });
}
