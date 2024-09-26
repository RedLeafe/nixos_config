{ moduleNamespace, ... }: # <- a function
# that returns a module
{config, pkgs, inputs, lib, self, ... }: {
  _file = ./fish.nix;
  options = {
    ${moduleNamespace}.fish.enable = lib.mkEnableOption "fish";
  };
  config = lib.mkIf config.${moduleNamespace}.fish.enable (let
    cfg = config.${moduleNamespace}.fish;
    fzfinit = pkgs.stdenv.mkDerivation {
      name = "fzfinit";
      builder = pkgs.writeText "builder.sh" /* bash */ ''
        source $stdenv/setup
        ${pkgs.fzf}/bin/fzf --fish > $out
      '';
    };
  in {
    programs.fish = {
      enable = true;
      interactiveShellInit = ''
        fish_vi_key_bindings
      '';
      promptInit = ''
        ${pkgs.oh-my-posh}/bin/oh-my-posh init fish --config ${../atomic-emodipt.omp.json} | source
        source ${fzfinit}
      '';
    };
  });
}
