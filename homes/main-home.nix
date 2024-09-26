{ config, pkgs, lib, self, inputs, username, stateVersion, home-modules, osConfig ? null, ...  }@args: let
in {
  imports = with home-modules; [
    alacritty
    ranger
    shell.bash
    shell.fish
    shell.zsh
    thunar
  ];
  home.username = username;
  home.homeDirectory = let
    homeDirPrefix = if pkgs.stdenv.hostPlatform.isDarwin then "Users" else "home";
    homeDirectory = "/${homeDirPrefix}/${username}";
  in 
  homeDirectory;
  programs.home-manager.enable = true;
  home.stateVersion = stateVersion;

  programs.git = {
    extraConfig = {
      core = {
        fsmonitor = "true";
      };
    };
  };

  moon_mods = {
    zsh.enable = true;
    bash.enable = true;
    fish.enable = true;
    alacritty.enable = true;
    thunar.enable = true;
    ranger.enable = true;
  };

  nix.gc = {
    automatic = true;
    frequency = "weekly";
    options = "-d";
  };

  home.shellAliases = {
    yolo = ''git add . && git commit -m "$(curl -fsSL https://whatthecommit.com/index.txt)" -m '(auto-msg whatthecommit.com)' -m "$(git status)" && git push'';
    lsnc = "lsd --color=never";
    la = "lsd -a";
    ll = "lsd -lh";
    l  = "lsd -alh";
    yeet = "rm -rf";
    dugood = ''${pkgs.writeShellScript "dugood" ''du -hd1 $@ | sort -hr''}'';
  };
  home.sessionVariables = {
    EDITOR = "nvim_for_u";
    JAVA_HOME = "${pkgs.jdk}";
  };
  nix.settings = {
    # substituters = [
    #   "https://nix-community.cachix.org"
    # ];
    # trusted-public-keys = [
    #   "nix-community.cachix.org-1:mB9FSh9qf2dCimDSUo8Zy7bkq5CX+/rkCWyvRCYg3Fs="
    # ];
  };

  xdg.enable = true;
  xdg.userDirs.enable = true;

  # Home Manager is pretty good at managing dotfiles. The primary way to manage
  # plain files is through 'home.file'.
  home.file = {
    # # Building this configuration will create a copy of 'dotfiles/screenrc' in
    # # the Nix store. Activating the configuration will then make '~/.screenrc' a
    # # symlink to the Nix store copy.
    # ".screenrc".source = dotfiles/screenrc;

    # # You can also set the file content immediately.
    # ".gradle/gradle.properties".text = ''
    #   org.gradle.console=verbose
    #   org.gradle.daemon.idletimeout=3600000
    # '';
  };

  # The home.packages option allows you to install Nix packages into your
  # environment.
  home.packages = let
    tmux_wrapped = pkgs.tmux.override (prev: {
      isAlacritty = true;
    });
    tx = pkgs.writeShellScriptBin "tx" /*bash*/''
      if ! echo "$PATH" | grep -q "${tmux_wrapped}/bin"; then
        export PATH=${tmux_wrapped}/bin:$PATH
      fi
      if [[ $(tmux list-sessions -F '#{?session_attached,1,0}' | grep -c '0') -ne 0 ]]; then
        selected_session=$(tmux list-sessions -F '#{?session_attached,,#{session_name}}' | tr '\n' ' ' | awk '{print $1}')
        exec tmux new-session -At $selected_session
      else
        exec tmux new-session
      fi
    '';
  in with pkgs; [
    inputs.birdeeSystems.birdeeVim.packages.${system}.nvim_for_u
    tmux_wrapped
    tx

    fira-code
    openmoji-color
    noto-fonts-emoji
    (nerdfonts.override { fonts = [ "FiraMono" "Go-Mono" ]; })

    openvpn
    openconnect
    snort
    vlc
    xfce.ristretto
    grex
    exfatprogs
    ntfs3g
    psensor
    btop
    nix-output-monitor
    nh
    nurl
    nix-info
    lazygit
    fastfetch
    docker-compose
    gnumake
    cmake
    gccgo
    gotools
    go-tools
    sqlite-interactive
    man-pages
    man-pages-posix
    _7zz
    python3
    gping
    wget
    openssl
    zsh
    tree
    fd
    fzf
    duf
    tldr
    lsof
    dos2unix
    noti
    bat
    lsd
    zip
    dig
    unzip
    git
    pciutils
    xclip
    xcp
    xsel
    xorg.xev
    xorg.xmodmap
    chromium
  ];
  fonts.fontconfig.enable = true;
  qt.platformTheme.name = "gtk3";
  qt.enable = true;
  qt.style.package = pkgs.adwaita-qt;
  qt.style.name = "adwaita-dark";
  gtk.enable = true;
  gtk.cursorTheme.package = pkgs.phinger-cursors;
  gtk.cursorTheme.name = "phinger-cursors";
  home.pointerCursor.package = pkgs.phinger-cursors;
  home.pointerCursor.name = "phinger-cursors";
  gtk.theme.package = pkgs.adw-gtk3;
  gtk.theme.name = "adw-gtk3-dark";
  # gtk.gtk3.extraCss = '''';
  # gtk.gtk3.extraConfig = {};
  # gtk.gtk4.extraCss = '''';
  # gtk.gtk4.extraConfig = {};
  gtk.iconTheme.package = pkgs.beauty-line-icon-theme;
  gtk.iconTheme.name = "BeautyLine";
}
