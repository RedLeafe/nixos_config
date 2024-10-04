# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, self, inputs, stateVersion, username, hostname, system-modules, ... }: let
in {
  imports = with system-modules; [
    alacritty
    shell.bash
    shell.zsh
    shell.fish
    lightdm
    i3
    LD
    AD
    WP
  ];

  moon_mods = {
    zsh.enable = true;
    bash.enable = true;
    fish.enable = true;

    alacritty.enable = true;
    lightdm.enable = true;
    i3.enable = true;
    i3.tmuxDefault = true;    

    LD.enable = true;
    AD.enable = true;
    AD.domain = "alien.moon.mine";
    WP.enable = true;
  };

  virtualisation.docker.enable = true;

  users.defaultUserShell = pkgs.zsh;

  services.clamav.daemon.enable = true;
  services.clamav.updater.enable = true;
  services.clamav.updater.interval = "weekly";

  environment.variables = {
  };
  environment.interactiveShellInit = ''
  '';
  environment.shellAliases = {
    lsnc = "${pkgs.lsd}/bin/lsd --color=never";
    la = "${pkgs.lsd}/bin/lsd -a";
    ll = "${pkgs.lsd}/bin/lsd -lh";
    l  = "${pkgs.lsd}/bin/lsd -alh";
  };

  users.users.${username} = {
    name = username;
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    initialPassword = "test";
    openssh.authorizedKeys.keys = [
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC43l4qRFhbaZRHbkbiuGJa9CmqBhF8ppnWk7yA4BbGEMWTXK8lnDak9jFVAQHk1UVpGJctR0u/E9Gxl2m7lIMV9fibcYYD34nmzm+ycod92uGq+g10mEWLgidl93+eE1NOt0x1jyfNiZ+tii6KFMQRSyLu68eD5SqOiT2V4Qh6GtFbIPWJQ6SXnOFCJG767ywB5wl+1sQFMkD1JJvi7KmuqekrvM5vvjFjQpHEezOXhn/cGx5ynk/xN/YaUYx93apGQ2blGm8ZIWuqegeR0nquhWa69fIpo7KfYqmxI016t7PZB6/RQmkJevr/d42WAS3kvp6nQ1cvidiiKx79mDMV operations@wrccdc.org"
      "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABgQDLEyyBJpJnaUHPNNOybf3ZiK0z3AkJ66fdzE+CMxlknY09mjcF6x2ZIkLeSgnnhNcoMF/7TCvNIt9g25nqX5V80oO7zkVZtisbRfx1hFnCrmYNFKdoh3dNY0D5qvl5kGl9SAnzI6SqPTbJzlVgqVeRPBB9pZXEnZ1bf8PxqfMvP+KJX1FHadAgP3twYFMBgKLeWz+a5gfEXFs2OJLSPaqvoR/7hq1Ovad6N3sn2hqf+Ke+50x7c0fwMTJTqbY8W3m0VZchPO/jReSl9bw1ZhtmpP06E2vlzkGsZbiQowESXGkhu9+700lDn76yeN+nf77+1bpHt6Wqqjf0gYImR6Xspb/dE2DZugs3zgcMFlr5/K5+oXKJ9CdICY5X1u/eV9nP/YUgHmaCb/uG96FCOBALV6a++JuuQttEQqkofVw+jeRc8RZvSWbDGFhP1rl5IAlYE4pQ4Y5zOtoiP+fyTrh3P6273Ql0VLr85e3Nzr+LPMRU9+5skxPQkehus8Ut2hc= marlowe@riomaggiore"
    ];
    # this is packages for nixOS user config.
    # packages = []; # empty because that is managed by home-manager
  };

  networking.hostName = hostname; # Define your hostname.
  # networking.wireless.enable = true;  # Enables wireless support via wpa_supplicant.

  # Configure network proxy if necessary
  # networking.proxy.default = "http://user:password@proxy:port/";
  # networking.proxy.noProxy = "127.0.0.1,localhost,internal.domain";

  # Enable networking
  # networking.networkmanager.enable = true;
  # networking.networkmanager.insertNameservers = [ "192.168.220.254" ];
  networking = {
    dhcpcd.enable = false;
    domain = "alien.moon.mine";
    search = [ "alien.moon.mine" ];
    interfaces.eth0.ipv4.addresses = [{
      address = "192.168.220.44";
      prefixLength = 24;
    }];
    defaultGateway = {
      address = "192.168.220.2";
      interface = "eth0";
    };
    nameservers = [ "192.168.220.254" ];
  };

  boot.kernelParams = [ "net.ifnames=0" "biosdevname=0" ];

  # Some programs need SUID wrappers, can be configured further or are
  # started in user sessions.
  # programs.mtr.enable = true;
  programs.gnupg.agent = {
    enable = true;
    pinentryPackage = pkgs.pinentry-curses;
    enableSSHSupport = true;
  };

  # List services that you want to enable:

  programs.ssh.pubkeyAcceptedKeyTypes = [
    "ssh-rsa"
    "ssh-ed25519"
  ];

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    ports = [ 22 ];
    settings = {
      PasswordAuthentication = false;
      AllowUsers = null; # Allows all users by default. Can be [ "user1" "user2" ]
      UseDns = true;
      X11Forwarding = false;
      PermitRootLogin = "prohibit-password"; # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
    };
  };
  services.fail2ban.enable = true;

  # firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 ];
  # networking.firewall.allowedUDPPorts = [ ... ];

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

  environment.systemPackages = with pkgs; [
    inputs.birdeeSystems.birdeeVim.packages.${system}.nvim_for_u
    fuse
    fuse3
    parted
    gparted
    sshfs-fuse
    socat
    nix-output-monitor
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
    lshw
    lsd
    bat
    wget
    tree
    zip
    _7zz
    unzip
    xclip
    xsel
    git
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
