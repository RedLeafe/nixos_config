{ config, pkgs, stateVersion, system-modules, hostconfig, inputs, ... }: let
  login_shell = "zsh";
  nerd_font_string = "FiraMono";
  installuser = "nixos";
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

  isoImage.contents = [
    { source = "${inputs.self}"; target = "/nixos_config";}
  ];

  environment.shellAliases = {
    lsnc = "ls --color=never";
    la = "ls -a";
    ll = "ls -l";
    l  = "ls -alh";
  };

  nixpkgs.config.allowUnfree = true;
  nix.settings.experimental-features = [ "nix-command" "flakes" ];
  services.libinput.enable = true;
  services.libinput.touchpad.disableWhileTyping = true;
  system.stateVersion = stateVersion;

  users.defaultUserShell = pkgs.${login_shell};
  system.activationScripts.silencezsh.text = ''
    [ ! -e "/home/${installuser}/.zshrc" ] && echo "# dummy file" > /home/${installuser}/.zshrc
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

  environment.systemPackages = (let

    scriptsForHosts = let
      listed = builtins.attrValues (builtins.mapAttrs (name: value: {
        host = name;
        inherit (value) admin;
        postdisko = if value ? postdisko then value.postdisko else (_: "");
        postinstall = if value ? postinstall then value.postinstall else (_: "");
      }) hostconfig);
      mkScriptsForHost = { host, admin, postdisko, postinstall }: let
        diskoscript = pkgs.writeShellScriptBin "disko-${host}-script" ''
          hostname=''${1:-'${host}'}
          username=''${2:-'${admin}'}
          shift 2
          [ ! -d /home/${installuser}/nixos_config ] && cp -r /iso/nixos_config /home/${installuser}
          sudo disko --mode disko --flake /iso/nixos_config#$hostname
          postcmds () {
            ${postdisko installuser}
          }
          postcmds "$hostname" "$username" "$@"
        '';
        # if it gets stuck you can run just this one without running disko part
        # so that it picks up more or less where it left off.
        installscript = pkgs.writeShellScriptBin "install-${host}-script" ''
          hostname=''${1:-'${host}'}
          username=''${2:-'${admin}'}
          shift 2
          [ ! -d /home/${installuser}/nixos_config ] && cp -r /iso/nixos_config /home/${installuser}
          sudo nixos-install --verbose --show-trace --flake /home/${installuser}/nixos_config#$hostname
          echo "please set password for user $username"
          sudo passwd --root /mnt $username
          umask 077
          sudo mkdir -p /mnt/home/$username
          sudo cp -rvL /home/${installuser}/nixos_config /mnt/home/$username/nixos_config
          sudo chmod -R u+w /mnt/home/$username/nixos_config
          postcmds () {
            ${postinstall installuser}
          }
          postcmds "$hostname" "$username" "$@"
        '';
        fullinstall = pkgs.writeShellScriptBin "OS-${host}-full" ''
          hostname=''${1:-'${host}'}
          username=''${2:-'${admin}'}
          ${diskoscript}/bin/disko-${host}-script "$hostname"
          ${installscript}/bin/install-${host}-script "$hostname" "$username"
        '';
      in [ diskoscript installscript fullinstall ];
    in builtins.concatLists (builtins.map mkScriptsForHost listed);

  in with pkgs; [
    inputs.disko.packages.${system}.default
    neovim
    git
    findutils
    coreutils
    xclip
  ] ++ scriptsForHosts);

}
