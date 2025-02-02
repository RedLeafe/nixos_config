{ moduleNamespace, inputs, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.xtermwm;
in {
  options = {
    ${moduleNamespace}.xtermwm = with lib; {
      enable = mkEnableOption "xterm as window manager";
      fontName = mkOption {
        default = "FiraMono Nerd Font";
        type = types.str;
      };
    };
  };
  config = lib.mkIf cfg.enable (let
    tx = pkgs.writeShellScriptBin "tx" ''
      if ! echo "$PATH" | grep -q "${pkgs.tmux}/bin"; then
        export PATH=${pkgs.tmux}/bin:$PATH
      fi
      if [[ $(tmux list-sessions -F '#{?session_attached,1,0}' | grep -c '0') -ne 0 ]]; then
        selected_session=$(tmux list-sessions -F '#{?session_attached,,#{session_name}}' | tr '\n' ' ' | awk '{print $1}')
        exec tmux new-session -At $selected_session
      else
        exec tmux new-session
      fi
    '';
  in {

    services.xserver.enable = true;
    services.displayManager.defaultSession = "xterm-installer";
    services.xserver.desktopManager.session = (let
      maximizer = "${inputs.maximizer.packages.${pkgs.system}.default}/bin/maximize_program";
      launchScript = pkgs.writeShellScript "mysh" /*bash*/ ''
        # a tiny c program that uses libX11 to make xterm fullscreen.
        ${maximizer} xterm > /dev/null 2>&1 &
        # tmux launcher script
        exec ${tx}/bin/tx
      '';
    in [
      { name = "xterm-installer";
        start = /*bash*/ ''
          ${pkgs.xorg.xrdb}/bin/xrdb -merge ${pkgs.writeText "Xresources" ''
            xterm*termName: xterm-256color
            xterm*faceName: ${cfg.fontName}
            xterm*faceSize: 12
            xterm*background: black
            xterm*foreground: white
            xterm*title: xterm
            xterm*loginShell: true
          ''}
          ${pkgs.xterm}/bin/xterm -name xterm -e ${launchScript} &
          waitPID=$!
        '';
      }
    ]);

    environment.systemPackages = [
      tx
      pkgs.tmux
    ];
  });
}
