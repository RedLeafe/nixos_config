{ moduleNamespace, ... }: # <- a function
# that returns a module
{ config, pkgs, self, inputs, lib, ... }: let
in {
  _file = ./default.nix;
  imports = [
  ];
  options = {
    ${moduleNamespace}.i3 = with lib.types; {
      enable = lib.mkEnableOption "i3 configuration";
      dmenu = {
        terminalStr = lib.mkOption {
          default = ''alacritty'';
          type = str;
        };
      };
      terminalStr = lib.mkOption {
        default = ''alacritty'';
        type = str;
      };
      extraSessionCommands = lib.mkOption {
        default = null;
        type = nullOr str;
      };
      updateDbusEnvironment = lib.mkEnableOption "updating of dbus session environment";
      tmuxDefault = lib.mkEnableOption "swap tmux default alacritty to mod+enter from mod+shift+enter";
      defaultLockerEnabled = lib.mkOption {
        default = true;
        type = bool;
        description = "default locker = i3lock + xss-lock";
      };
      prependedConfig = lib.mkOption {
        default = '''';
        type = str;
      };
      appendedConfig = lib.mkOption {
        default = '''';
        type = str;
      };
      background = lib.mkOption {
        default = ./background.png;
        type = nullOr path;
      };
      lockerBackground = lib.mkOption {
        default = ./background.png;
        type = nullOr path;
      };
    };
  };
  config = lib.mkIf config.${moduleNamespace}.i3.enable (let
    cfg = config.${moduleNamespace}.i3;

    tx = pkgs.writeShellScriptBin "tx" /*bash*/''
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

    i3Config = (let
        fehBG = (pkgs.writeShellScript "fehBG" (if cfg.background != null then ''
          exec ${pkgs.feh}/bin/feh --no-fehbg --bg-scale ${cfg.background} "$@"
        '' else "exit 0"));
        termCMD = if cfg.tmuxDefault then ''${cfg.terminalStr} -e ${tx}/bin/tx'' else ''${cfg.terminalStr}'';
        xtraTermCMD = if cfg.tmuxDefault then ''${cfg.terminalStr}'' else ''${cfg.terminalStr} -e ${tx}/bin/tx'';
      in ''
          set $fehBG ${fehBG}
          set $termCMD ${termCMD}
          set $xtraTermCMD ${xtraTermCMD}
          set $termSTR ${cfg.terminalStr}
          ${cfg.prependedConfig}
        '' + builtins.readFile ./config + (if cfg.defaultLockerEnabled then ''
          exec --no-startup-id xss-lock --transfer-sleep-lock -- i3lock --nofork
        '' else "") + cfg.appendedConfig);

  in {

    services.displayManager.defaultSession = lib.mkDefault "none+i3";
    services.xserver.windowManager.i3 = {
      enable = true;
      updateSessionEnvironment = cfg.updateDbusEnvironment;
      configFile = "${ pkgs.writeText "config" i3Config }";
      extraSessionCommands = lib.mkIf (cfg.extraSessionCommands != null) cfg.extraSessionCommands;
    };
    # services.xserver.updateDbusEnvironment = cfg.updateDbusEnvironment;
    environment.systemPackages = (let
      dmenu = pkgs.writeShellScriptBin "dmenu_run" (/* bash */''
        dmenu() {
          ${pkgs.dmenu}/bin/dmenu "$@"
        }
        dmenu_path() {
          ${pkgs.dmenu}/bin/dmenu_path "$@"
        }
        TERMINAL=${cfg.dmenu.terminalStr}
      '' + (builtins.readFile ./dmenu_recency.sh));
      dmenuclr_recent = ''${pkgs.writeShellScriptBin "dmenuclr_recent" (/*bash*/''
        cachedir=''${XDG_CACHE_HOME:-"$HOME/.cache"}
        cache="$cachedir/dmenu_recent"
        rm $cache
      '')}'';
      i3status = (pkgs.writeShellScriptBin "i3status" ''
        exec ${pkgs.i3status}/bin/i3status --config ${pkgs.writeText "i3bar" (pkgs.callPackage ./i3bar.nix {})} "$@"
      '');
      i3lock = (pkgs.writeShellScriptBin "i3lock" ''
        exec ${pkgs.i3lock}/bin/i3lock -t -i ${cfg.lockerBackground} "$@"
      '');
    in
    with pkgs; with pkgs.xfce; (if cfg.defaultLockerEnabled then [
      xss-lock
      i3lock #default i3 screen locker
    ] else []) ++ [
      i3status #default i3 status bar
      libnotify
      dmenu #application launcher most people use
      dmenuclr_recent
      pa_applet
      pavucontrol
      networkmanagerapplet
      xfce4-volumed-pulse
      lm_sensors
      glib # for gsettings
      gtk3.out # gtk-update-icon-cache
      desktop-file-utils
      shared-mime-info # for update-mime-database
      polkit_gnome
      xdg-utils
      xdg-user-dirs
      garcon
      libxfce4ui
      xfce4-power-manager
      xfce4-notifyd
      xfce4-screenshooter
      xfce4-taskmanager
      libsForQt5.qt5.qtquickcontrols2
      libsForQt5.qt5.qtgraphicaleffects
      tmux
      tx
    ]);

    # for tmux
    security.wrappers = {
      utempter = {
        source = "${pkgs.libutempter}/lib/utempter/utempter";
        owner = "root";
        group = "utmp";
        setuid = false;
        setgid = true;
      };
    };

  });
}
