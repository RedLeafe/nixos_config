{ config, pkgs, stateVersion, system-modules, hostname, username, inputs, ... }: let
  login_shell = "zsh";
  nerd_font_string = "FiraMono";
in {
  imports = with system-modules; [
    ./minimal-graphical-base.nix
    shell.${login_shell}
    ranger
    xtermwm
  ] ++ (if login_shell == "bash" then [] else [
    shell.bash
  ]);

  moon_mods = {
    xtermwm.enable = true;
    xtermwm.fontName = "${nerd_font_string} Nerd Font";
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
    # if it gets stuck you can run just this one without running disko part
    # so that it picks up more or less where it left off.
    installscript = pkgs.writeShellScript "install" ''
      hostname=''${1:-'${hostname}'}
      username=''${2:-'${username}'}
      [ ! -d /home/nixos/nixos_config ] && cp -r /iso/nixos_config /home/nixos
      sudo nixos-install --verbose --show-trace --flake /home/nixos/nixos_config#$hostname
      echo "please set password for user $username"
      sudo passwd --root /mnt $username
      umask 077
      sudo mkdir -p /mnt/home/$username
      sudo cp -rvL /home/nixos/nixos_config /mnt/home/$username/nixos_config
      [ -d /home/nixos/restored_data ] && sudo cp -rvL /home/nixos/restored_data /mnt/home/$username/restored_data
      sudo chmod -R u+w /mnt/home/$username/nixos_config
      sudo chown -R $username:users /mnt/home/$username/nixos_config
      [ -d /mnt/home/$username/restored_data ] && sudo chown -R $username:users /mnt/home/$username/restored_data
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
    { source = "${inputs.self}"; target = "/nixos_config";}
  ];

  environment.systemPackages = with pkgs; [
    inputs.disko.packages.${system}.default
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

  system.stateVersion = stateVersion;

}
