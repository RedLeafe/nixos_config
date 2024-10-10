{ config, pkgs, lib, modulesPath, inputs, stateVersion, username, authorized_keys, hostname, system-modules, nixpkgs, ... }: let
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
    domainname = "10.100.136.42";
    lfs = true;
  };

  moon_mods.sshgit = {
    enable = true;
    AD_support = true;
    default_git_user = "${username}";
    default_git_email = "${username}@alien.moon.mine";
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
    packages = (let
      adjoin = pkgs.writeShellScriptBin "adjoin" ''
        sudo ${pkgs.adcli}/bin/adcli join -U Administrator "$@"
      '';
      yeet_trash = pkgs.writeShellScriptBin "yeet_trash" ''
        nix-collect-garbage --delete-old
        sudo nix-collect-garbage --delete-old
      '';
      GETDUMP = pkgs.writeShellScriptBin "GET_GIT_DUMP" ''
        sudo systemctl restart gitea-dump.service
        FILENAME="$(sudo ls -1 '${config.services.gitea.dump.backupDir}' | sort -t '-' -k3 -nr | head -n 1)"
        umask 077
        sudo cp "${config.services.gitea.dump.backupDir}$FILENAME" .
        sudo chown ${username}:${username} "$FILENAME"
      '';
      RESTOREDUMP = pkgs.writeShellScriptBin "RESTORE_GIT_DUMP" ''
        PATH="${lib.makeBinPath (with pkgs; [ coreutils sqlite unzip ])}:$PATH"
        DUMPFILE="$1"
        [ -z "$DUMPFILE" ] && DUMPFILE="$(ls -1 /home/${username}/gitea-dump-*.zip | sort -t '-' -k3 -nr | head -n 1)"
        OGDIR="$(realpath .)"
        TEMPDIR="$(mktemp -d)"
        umask 007
        if [ -z "$DUMPFILE" ]; then
          echo "Usage: $0 <path_to_gitea_dump>"
          exit 1
        fi
        unzip -d "$TEMPDIR" "$DUMPFILE" || { echo "Failed to unzip $DUMPFILE"; exit 1; }
        sudo chown -R ${username}:${username} "$TEMPDIR" || { echo "Failed to change ownership of created directory"; exit 1; }
        cd "$TEMPDIR" && {
          [ -d data ] && sudo mv data/* '${config.services.gitea.stateDir}/data' || echo "No data directory found"
          [ -d custom ] && sudo mv custom/* '${config.services.gitea.customDir}' || echo "No custom directory found"
          [ -d log ] && sudo mv log/* '${config.services.gitea.settings.log.ROOT_PATH}' || echo "No log directory found"
          [ -d repos ] && sudo mv repos/* '${config.services.gitea.repositoryRoot}' || echo "No repos directory found"
          sudo sqlite3 '${config.services.gitea.database.path}' <gitea-db.sql || { echo "Database restore failed"; exit 1; }
        } && \
        sudo chown -R '${config.services.gitea.user}:${config.services.gitea.user}' '${config.services.gitea.stateDir}' || { echo "Failed to change ownership back to ${config.services.gitea.user}"; exit 1; }
        cd "$OGDIR" && rm -rf "$TEMPDIR"
      '';
    in [
      GETDUMP
      RESTOREDUMP
      adjoin
      yeet_trash
    ]);
  };
}
