{ moduleNamespace, ... }: # <- a function
# that returns a module
{config, pkgs, inputs, self, lib, ... }: {
  _file = ./bash.nix;
  options = {
    ${moduleNamespace}.bash.enable = lib.mkEnableOption "bash";
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
      promptInit = ''
        eval "$(${pkgs.oh-my-posh}/bin/oh-my-posh init bash --config ${../atomic-emodipt.omp.json})"
        source ${fzfinit}
      '';
    };
  });
}
