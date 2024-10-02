{ config, pkgs, self, stateVersion, system-modules, hostname, username, inputs, ... }: let
  tmux_new = pkgs.tmux.override {
    isAlacritty = false;
  };
  tx = pkgs.writeShellScriptBin "tx" ''
    if ! echo "$PATH" | grep -q "${tmux_new}/bin"; then
      export PATH=${tmux_new}/bin:$PATH
    fi
    if [[ $(tmux list-sessions -F '#{?session_attached,1,0}' | grep -c '0') -ne 0 ]]; then
      selected_session=$(tmux list-sessions -F '#{?session_attached,,#{session_name}}' | tr '\n' ' ' | awk '{print $1}')
      exec tmux new-session -At $selected_session
    else
      exec tmux new-session
    fi
  '';
  login_shell = "zsh";
  nerd_font_string = "FiraMono";

in {
  imports = with system-modules; [
    ./minimal-graphical-base.nix
    shell.${login_shell}
    ranger
  ] ++ (if login_shell == "bash" then [] else [
    shell.bash
  ]);

  moon_mods = {
    ${login_shell}.enable = true;
    ranger = {
      enable = true;
      withoutDragon = true;
    };
  } // (if login_shell == "bash" then {} else {
    bash.enable = true;
  });

  isoImage.isoBaseName = "space_dust_installer";

  environment.shellAliases = let
    diskoscript = pkgs.writeShellScript "disko" ''
      hostname=''${1:-'${hostname}'}
      [ ! -d /home/nixos/nixos_config ] && cp -r /iso/nixos_config /home/nixos
      sudo disko --mode disko --flake /iso/nixos_config#$hostname
    '';
    installscript = pkgs.writeShellScript "install" ''
      hostname=''${1:-'${hostname}'}
      username=''${2:-'${username}'}
      [ ! -d /home/nixos/nixos_config ] && cp -r /iso/nixos_config /home/nixos
      sudo nixos-install --show-trace --flake /home/nixos/nixos_config#$hostname
      echo "please set password for user $username"
      sudo passwd --root /mnt $username
      umask 077
      sudo mkdir -p /mnt/home/$username
      sudo cp -rvL /home/nixos/nixos_config /mnt/home/$username/nixos_config
      sudo chmod -R u+w /mnt/home/$username/nixos_config
    '';
  in {
    SPACEOS = "${pkgs.writeShellScript "SPACEOS" ''
      hostname=''${1:-'${hostname}'}
      username=''${2:-'${username}'}
      ${diskoscript} "$hostname"
      ${installscript} "$hostname" "$username"
    ''}";
    SPACEOS-disko = "${diskoscript}";
    SPACEOS-install = "${installscript}";
    lsnc = "ls --color=never";
    la = "ls -a";
    ll = "ls -l";
    l  = "ls -alh";
  };

  isoImage.contents = [
    { source = "${self}"; target = "/nixos_config";}
  ];

  environment.systemPackages = with pkgs; [
    inputs.disko.packages.${system}.default
    tmux_new
    tx
    neovim
    git
    findutils
    coreutils
    xclip
  ];

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  services.libinput.enable = true;
  services.libinput.touchpad.disableWhileTyping = true;

  users.defaultUserShell = pkgs.${login_shell};

  system.activationScripts.silencezsh.text = ''
    [ ! -e "/home/nixos/.zshrc" ] && echo "# dummy file" > /home/nixos/.zshrc
  '';

  fonts.packages = with pkgs; [
    (nerdfonts.override { fonts = [ "${nerd_font_string}" ]; })
  ];
  fonts.fontconfig = {
    enable = true;
    defaultFonts = {
      serif = [ "${nerd_font_string} Nerd Font" ];
      sansSerif = [ "${nerd_font_string} Nerd Font" ];
      monospace = [ "${nerd_font_string} Nerd Font" ];
    };
  };
  fonts.fontDir.enable = true;

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
          xterm*faceName: ${nerd_font_string} Nerd Font
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

  system.stateVersion = stateVersion;

}
