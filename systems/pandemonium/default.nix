{ pkgs, lib, modulesPath, inputs, stateVersion, username, authorized_keys, hostname, system-modules, nixpkgs, ... }: let
in {
  imports = with system-modules; [
    "${modulesPath}/virtualisation/vmware-guest.nix"
    gitea
    sshgit
    ../vm.nix
    ./hardware-configuration.nix
  ];
  virtualisation.vmware.guest.enable = true;

  moon_mods.gitea = {
    enable = true;
    domainname = "192.168.220.254";
    lfs = true;
    https = false;
  };

  moon_mods.sshgit = {
    enable = true;
    AD_support = true;
    default_git_user = "${username}";
    default_git_email = "${username}@alien.moon.mine";
    authorized_keys = authorized_keys;
    fail2ban = true;
    settings = {
      AllowUsers = null;
      PasswordAuthentication = false;
      UseDns = true;
      X11Forwarding = true;
      PermitRootLogin = "prohibit-password"; # "yes", "without-password", "prohibit-password", "forced-commands-only", "no"
    };
  };

  networking = {
    dhcpcd.enable = false;
    domain = "alien.moon.mine";
    search = [ "alien.moon.mine" ];
    interfaces.eth0.ipv4.addresses = [{
      address = "192.168.220.42";
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
  networking.firewall.allowedTCPPorts = [ 22 80 443 ];
  # networking.firewall.allowedUDPPorts = [ ... ];

  users.users.${username} = {
    name = username;
    shell = pkgs.zsh;
    isNormalUser = true;
    description = "";
    extraGroups = [ "networkmanager" "wheel" "docker" ];
    initialPassword = "test";
    openssh.authorizedKeys.keys = authorized_keys;
    # TODO: add setup, save, restore scripts
    packages = [
    ];
  };
}
