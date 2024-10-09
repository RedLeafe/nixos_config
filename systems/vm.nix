# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).
{ config, pkgs, lib, inputs, stateVersion, username, hostname, system-modules, authorized_keys, ... }: let
in {
  imports = with system-modules; [
    shell.bash
    shell.zsh
    shell.fish
    ranger
    xtermwm
    LD
    AD
  ];

  moon_mods.zsh.enable = true;
  moon_mods.bash.enable = true;
  moon_mods.fish.enable = true;
  moon_mods.ranger.enable = true;
  moon_mods.xtermwm = {
    enable = true;
    fontName = "FiraMono Nerd Font";
  };

  moon_mods.LD.enable = true;

  moon_mods.AD = {
    enable = true;
    domain = "alien.moon.mine";
    domain_short = "alien";
    domain_controller = "kerberos.alien.moon.mine";
    ldap_search_base = "CN=Users,DC=alien,DC=moon,DC=mine";
  };

  swapDevices = let
    GB = v: v*1024;
  in [ {
    device = "/var/lib/swapfile";
    size = GB 3;
  } ];

  # Bootloader.
  boot.loader.timeout = 3;
  boot.loader.grub.enable = true;

  # disko sets this for us and will throw if we set it
  # boot.loader.grub.device = [ "/dev/sda" ];

  /* if you needed to swap it to an efi partition
     you could try these:
    boot.loader.grub.efiSupport = true;
    boot.loader.grub.efiInstallAsRemovable = true;
    boot.loader.efi.canTouchEfiVariables = true;
  */

  networking.hostName = hostname; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  # networking.networkmanager.enable = true;
  # networking.networkmanager.insertNameservers = [ "192.168.220.254" ];

  virtualisation.docker.enable = true;

  users.defaultUserShell = pkgs.zsh;

  services.clamav.daemon.enable = true;
  services.clamav.updater.enable = true;
  services.clamav.updater.interval = "weekly";

  system.activationScripts.silencezsh.text = ''
    for homedir in /home/*; do
      [ -d "$homedir" ] && [ ! -e "$homedir/.zshrc" ] && echo "# ssshhh" > "$homedir/.zshrc"
    done
  '';

  environment.variables = {
    EDITOR = "nvim";
  };
  environment.interactiveShellInit = ''
  '';
  environment.shellAliases = {
    lsnc = "${pkgs.lsd}/bin/lsd --color=never";
    la = "${pkgs.lsd}/bin/lsd -a";
    ll = "${pkgs.lsd}/bin/lsd -lh";
    l  = "${pkgs.lsd}/bin/lsd -alh";
  };

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
    enableSSHSupport = true;
  };

  security = {
    pam = {
      makeHomeDir.umask = "077";
      services.login.makeHomeDir = true;
    };
  };

  # Set your time zone.
  time.timeZone = "America/Los_Angeles";

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";

  i18n.extraLocaleSettings = {
    LC_ADDRESS = "en_US.UTF-8";
    LC_IDENTIFICATION = "en_US.UTF-8";
    LC_MEASUREMENT = "en_US.UTF-8";
    LC_MONETARY = "en_US.UTF-8";
    LC_NAME = "en_US.UTF-8";
    LC_NUMERIC = "en_US.UTF-8";
    LC_PAPER = "en_US.UTF-8";
    LC_TELEPHONE = "en_US.UTF-8";
    LC_TIME = "en_US.UTF-8";
  };

  # Allow unfree packages
  nixpkgs.config.allowUnfree = true;
  # Allow flakes and new command
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  nix.settings.auto-optimise-store = true;

  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "-d";
    persistent = true;
  };

  # Configure keymap in X11
  services.xserver.xkb = {
    layout = "us";
    variant = "";
  };
  # Enable touchpad support (enabled default in most desktopManager).
  services.libinput.enable = true;
  services.libinput.touchpad.disableWhileTyping = true;

  fonts.packages = with pkgs; [
    fira-code
    openmoji-color
    noto-fonts-emoji
    (nerdfonts.override { fonts = [ "FiraMono" ]; })
  ];
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [ "FiraMono Nerd Font" ];
      sansSerif = [ "FiraMono Nerd Font" "FiraCode" ];
      monospace = [ "FiraMono Nerd Font" ];
      emoji = [ "OpenMoji Color" "OpenMoji" "Noto Color Emoji" ];
    };
  };
  fonts.fontDir.enable = true;

  users.users.root.openssh.authorizedKeys.keys = authorized_keys;

  environment.systemPackages = with pkgs; [
    neovim
    fuse
    fuse3
    parted
    gparted
    sshfs-fuse
    socat
    screen
    tcpdump
    sdparm
    hdparm
    smartmontools # for diagnosing hard disks
    nix-info
    pciutils
    usbutils
    nvme-cli
    unzip
    zip
    exfat
    exfatprogs
    coreutils-full
    findutils
    lshw
    lsd
    bat
    fd
    fzf
    wget
    tree
    nix-tree
    zip
    _7zz
    unzip
    xclip
    xsel
    ntfs3g
  ];

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = stateVersion; # Did you read the comment?

}
