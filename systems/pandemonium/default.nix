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
    PAM_support = true;
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
    # NOTE: administration scripts
    packages = (let
      adjoin = pkgs.writeShellScriptBin "adjoin" ''
        sudo ${pkgs.adcli}/bin/adcli join -U Administrator "$@"
      '';
      yeet_trash = pkgs.writeShellScriptBin "yeet_trash" ''
        sudo nix-collect-garbage --delete-old
        nix-collect-garbage --delete-old
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
      GETDUMP = pkgs.writeShellScriptBin "GET_GIT_DUMP" ''
        OUTDIR="''${1:-/home/${username}}"
        sudo systemctl restart gitea-dump.service
        FILENAME="$(sudo ls -1 '${config.services.gitea.dump.backupDir}' | sort -t '-' -k3 -nr | head -n 1)"
        umask 077
        sudo cp "${config.services.gitea.dump.backupDir}/$FILENAME" "$OUTDIR"
        sudo chown ${username}:users "$OUTDIR/$FILENAME"
      '';
      GITEA_REGEN_HOOKS = pkgs.writeShellScriptBin "GITEA_REGEN_HOOKS" ''
        OGDIR="$(realpath .)" && \
        cd "${config.services.gitea.package}/bin" && \
        [ -z "$1" ] && {
          sudo -u gitea ./gitea -c ${config.services.gitea.customDir}/conf/app.ini admin regenerate hooks
        } || {
          sudo -u gitea ./gitea -c ${config.services.gitea.customDir}/conf/app.ini "$@"
        } && \
        cd "$OGDIR"
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
        giteadirs=(
          '${config.services.gitea.stateDir}'
          '${config.services.gitea.lfs.contentDir}'
          '${config.services.gitea.stateDir}/data'
          '${config.services.gitea.customDir}'
          '${config.services.gitea.settings.log.ROOT_PATH}'
          '${config.services.gitea.repositoryRoot}'
          '${builtins.dirOf config.services.gitea.database.path}'
        )
        DBPATH='${config.services.gitea.database.path}'
        sudo unzip -d "$TEMPDIR" "$DUMPFILE" || { echo "Failed to unzip $DUMPFILE"; exit 1; }
        sudo chown -R ${username}:users "$TEMPDIR" || { echo "Failed to change ownership of created directory"; exit 1; }
        cd "$TEMPDIR" && {
          sudo systemctl stop gitea.service && \
          sudo mkdir -p "''${giteadirs[@]}" && \
          sudo chown -R ${username}:users "''${giteadirs[@]}"
          [ -d data/lfs ] && mv -f data/lfs/* "''${giteadirs[1]}" || echo "No lfs directory found"
          [ -d data ] && mv -f data/* "''${giteadirs[2]}" || echo "No data directory found"
          [ -d custom ] && mv -f custom/* "''${giteadirs[3]}" || echo "No custom directory found"
          [ -d log ] && mv -f log/* "''${giteadirs[4]}" || echo "No log directory found"
          [ -d repos ] && mv -f repos/* "''${giteadirs[5]}" || echo "No repos directory found"
          sqlite3 "$DBPATH" <gitea-db.sql || echo "Database restore possibly failed?";
        }
        for dir in "''${giteadirs[@]}"; do
          sudo chown -R '${config.services.gitea.user}:${config.services.gitea.user}' "$dir" || echo "failed to change ownership of $dir to ${config.services.gitea.user}"
        done
        cd "$OGDIR" && rm -rf "$TEMPDIR"
        sudo systemctl restart gitea.service
        sleep 1
        ${GITEA_REGEN_HOOKS}/bin/GITEA_REGEN_HOOKS
      '';
    in [
      GITEA_REGEN_HOOKS
      GETDUMP
      RESTOREDUMP
      adjoin
      yeet_trash
      genAdminSSHkey
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
        TEADUMP="$(realpath "$1" 2> /dev/null)"
        ADPASS="$2"
        echo "fixing nixos config permissions"
        sudo chown -R ${username}:users /home/${username}
        echo "joining AD"
        if [[ -z "$ADPASS" ]]; then
          ${adjoin}/bin/adjoin
        else
          ${adjoin}/bin/adjoin --stdin-password <<< "$ADPASS"
        fi
        ${RESTOREDUMP}/bin/RESTORE_GIT_DUMP "$TEADUMP"
        ${genAdminSSHkey}/bin/genAdminSSHkey
        rm -f /home/${username}/.zsh_history
        echo "Initialization complete."
        echo "please reboot the machine to authenticate logins with AD"
      '')
    ]);
  };
}
