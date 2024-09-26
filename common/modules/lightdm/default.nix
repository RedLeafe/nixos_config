{ moduleNamespace, ... }: # <- a function
# that returns a module
{ config, pkgs, self, inputs, lib, ... }: {
  _file = ./default.nix;
  imports = [
  ];
  options = {
    ${moduleNamespace}.lightdm = with lib.types; {
      enable = lib.mkEnableOption "lightdm module";
      sessionCommands = lib.mkOption {
        default = null;
        type = nullOr str;
      };
      dpi = lib.mkOption {
        default = null;
        type = nullOr int;
      };
    };
  };
  config = lib.mkIf config.${moduleNamespace}.lightdm.enable (let
    cfg = config.${moduleNamespace}.lightdm;
  in {
    # Enable the X11 windowing system.
    services.xserver.enable = true;
    services.xserver.desktopManager.xterm.enable = false;

    services.xserver.dpi = lib.mkIf (cfg.dpi != null) cfg.dpi;

    services.xserver.displayManager = {
      lightdm = {
        enable = true;
        greeter = {
          enable = true;
        };
        greeters.gtk.enable = true;
        extraConfig = ''
        '';
      };
      sessionCommands = lib.mkIf (cfg.sessionCommands != null) cfg.sessionCommands;
    };
    # services.displayManager.defaultSession = lib.mkdefault "none+i3";

    environment.systemPackages = [
    ];

    services.dbus.packages = [
    ];

    qt.platformTheme = "gtk2";

    xdg.portal.enable = true;
    xdg.portal.extraPortals = with pkgs; [
      xdg-desktop-portal
      xdg-desktop-portal-gtk
      # libsForQt5.xdg-desktop-portal-kde
      # xdg-desktop-portal-gnome
      xdg-dbus-proxy
    ];
    xdg.portal.config.common.default = "*";

    programs.xfconf.enable = true;

    services.dbus.enable = true;
    services.xserver.updateDbusEnvironment = true;
    programs.gdk-pixbuf.modulePackages = with pkgs; [ gdk-pixbuf librsvg  ];

    programs.dconf.enable = true;
    services.upower.enable = true;
    services.udisks2.enable = true;
    services.gnome.glib-networking.enable = true;
    services.gvfs.enable = true;
    services.tumbler.enable = true;
    services.system-config-printer.enable = true;

    environment.pathsToLink = [
      "/share/xfce4"
      "/lib/xfce4"
      "/share/gtksourceview-3.0"
      "/share/gtksourceview-4.0"
    ];

  });
}
