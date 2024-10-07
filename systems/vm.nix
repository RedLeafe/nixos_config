# Edit this configuration file to define what should be installed on
# your system.  Help is available in the configuration.nix(5) man page
# and in the NixOS manual (accessible by running ‘nixos-help’).

{ config, pkgs, lib, inputs, stateVersion, username, hostname, system-modules, authorized_keys, ... }: let
  git_server_home_dir = "/var/lib/git-server";
in {
  imports = with system-modules; [
    shell.bash
    shell.zsh
    shell.fish
    ranger
    xtermwm
    LD
    AD
    WP
    sshgit
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
  moon_mods.WP.enable = true;

  moon_mods.sshgit = {
    enable = true;
    AD_support = true;
    default_git_user = "pluto";
    default_git_email = "pluto@lunarlooters.com";
    authorized_keys = authorized_keys;
    fail2ban = true;
    settings = {
      PasswordAuthentication = false;
      UseDns = true;
      X11Forwarding = false;
      PermitRootLogin = "prohibit-password"; # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
    };
    git_home_dir = git_server_home_dir;
    git_shell_scripts = {
      # example = ''
      #   echo "example script"
      # '';
    };
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

  # firewall.
  networking.firewall.enable = true;
  networking.firewall.allowedTCPPorts = [ 22 80 443 3306 ];
  # networking.firewall.allowedUDPPorts = [ ... ];

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

  users.users.${username} = {
    name = username;
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    initialPassword = "test";
    openssh.authorizedKeys.keys = authorized_keys;
    # NOTE: administration scripts
    packages = let
      dbpkg = config.services.mysql.package;
      adjoin = pkgs.writeShellScriptBin "adjoin" ''
        sudo ${pkgs.adcli}/bin/adcli join -U Administrator "$@"
      '';
      dumpDBall = pkgs.writeShellScriptBin "dumpDBall" ''
        outfile="''${1:-./dump.sql}"
        echo "enter the database root user's password:"
        sudo ${dbpkg}/bin/mysqldump -u root -p --all-databases > "$outfile"
      '';
      restoreDBall = pkgs.writeShellScriptBin "restoreDBall" ''
        infile="''${1:-./dump.sql}"
        if [ ! -e "$infile" ]; then
          echo "Error: $infile not found"
        else
          echo "enter the database root user's password:"
          sudo ${dbpkg}/bin/mysql -u root -p < "$infile"
        fi
      '';
      yeet_trash = pkgs.writeShellScriptBin "pluto_trash" ''
        nix-collect-garbage --delete-old
        sudo nix-collect-garbage --delete-old
      '';
      genAdminSSHkey = pkgs.writeShellScriptBin "genAdminSSHkey" ''
        mkdir -p /home/${username}/.ssh
        if [[ ! -f /home/${username}/.ssh/id_ed25519 ]]; then
          ssh-keygen -q -f /home/${username}/.ssh/id_ed25519 -N ""
          cp -f /home/${username}/.ssh/id_ed25519.pub /home/${username}/nixos_config/common/auth_keys/${username}.pub
        else
          echo "SSH key already exists, skipping key generation."
        fi
      '';
      dumpGitRepos = pkgs.writeShellScriptBin "dumpGitRepos" ''
        outfile="''${1:-./repobackup.zip}"
        sudo ${pkgs.zip}/bin/zip -r -9 "$outfile" "${git_server_home_dir}"
      '';
      # NOTE: Assumes zip was made with the above command
      restoreGitRepos = pkgs.writeShellScriptBin "restoreGitRepos" ''
        repozip="''${1:-./repobackup.zip}"
        if [ ! -e "$repozip" ]; then
          echo "Error: $repozip not found"
        else
          tempdir=$(mktemp -d)
          ${pkgs.unzip}/bin/unzip -d "$tempdir" "$repozip"
          mkdir -p "${git_server_home_dir}"
          sudo cp -r $tempdir/${git_server_home_dir}/* "${git_server_home_dir}"
        fi
      '';
    in [
      adjoin
      dumpDBall
      restoreDBall
      yeet_trash
      genAdminSSHkey
      dumpGitRepos
      restoreGitRepos
      (pkgs.writeShellScriptBin "initial_post_installation_script" ''
        if [[ "$USER" != "${username}" ]]; then
          echo "Error: script must be run as the user ${username}"
          exit 1
        fi
        export PATH="$PATH:${lib.makeBinPath (with pkgs; [
          git
          openssh
          coreutils
        ])}"
        WPDBDUMP="$(realpath "$1" 2> /dev/null)"
        REPOZIP="$(realpath "$2" 2> /dev/null)"
        ADPASSFILE="$(realpath "$3" 2> /dev/null)"
        ${genAdminSSHkey}/bin/genAdminSSHkey
        echo "fixing nixos config permissions"
        sudo chown -R ${username}:users /home/${username}/nixos_config
        cd /home/${username}/nixos_config && git init && git add . && \
        git commit -m "initial nixos config" && git branch -M master && \
        git remote add origin git@localhost:nixos_config.git
        echo "joining AD"
        if [[ ! -f "$ADPASSFILE" ]]; then
          ${adjoin}/bin/adjoin
        else
          ${adjoin}/bin/adjoin --stdin-password <<< "$(cat "$ADPASSFILE")"
        fi
        ${restoreDBall}/bin/restoreDBall "$WPDBDUMP"
        ${restoreGitRepos}/bin/restoreGitRepos "$REPOZIP"
        /home/${username}/nixos_config/scripts/build
        ssh git@localhost 'new-remote nixos_config' && \
        git push -u origin master
        echo "Initialization complete."
        echo "please reboot the machine to authenticate logins with AD"
      '')
    ];
  };

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
