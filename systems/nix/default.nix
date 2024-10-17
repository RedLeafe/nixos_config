{ config, pkgs, lib, modulesPath, inputs, stateVersion, username, hostname, system-modules, authorized_keys, nixpkgs, ... }: let
  sqldbpkg = config.services.mysql.package;
  siteName = "LunarLooters";
  backupDir = "/backup";
  
in {
  imports = with system-modules; [
    "${modulesPath}/virtualisation/vmware-guest.nix"
    ../vm.nix
    ./hardware-configuration.nix
    WP
    sshgit
  ];
  virtualisation.vmware.guest.enable = true;

  nix.settings = {
    # bash-prompt-prefix = "✓";
    trusted-substituters = [
      "http://10.100.136.42/nix_cache/"
    ];
    # trusted-public-keys = [
    # ];
  };
  moon_mods.WP = {
    enable = true;
    inherit siteName backupDir;
    mailaddr = "noreply@lunarlooters.com";
  };

  moon_mods.sshgit = {
    enable = true;
    AD_support = true;
    default_git_user = "${username}";
    default_git_email = "${username}@alien.moon.mine";
    repo_clone_hostname = "10.100.136.44";
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
      get_wp_dump = pkgs.writeShellScriptBin "get_wp_dump" ''
        OUTDIR="''${1:-/home/${username}}"
        sudo systemctl restart backup_runner.service
        while true; do
          STATUS=$(sudo systemctl is-active backup_runner.service)
          if [ "$STATUS" == "inactive" ]; then
            echo "Service finished successfully."
            break
          elif [ "$STATUS" == "failed" ]; then
            echo "Whoops, service failed."
            exit 1
          fi
          sleep 1
        done
        sudo cp ${backupDir}/wp-dump.tar.gz "$OUTDIR"
        sudo chown ${username}:users "$OUTDIR/wp-dump.tar.gz"
      '';
      restoreWP = pkgs.writeShellScriptBin "restoreWP" (let
        wp_dp_name = config.services.wordpress.sites.${siteName}.database.name;
        wp_user = config.services.wordpress.sites.${siteName}.database.user;
        wp_ups = config.services.wordpress.sites.${siteName}.uploadsDir;
        webgroup = config.services.${config.services.wordpress.webserver}.group;
      in /*bash*/ ''
        export PATH="${lib.makeBinPath (with pkgs; [ sqldbpkg coreutils gnutar gzip ])}:$PATH";
        infile="''${1:-/home/${username}/wp-dump.tar.gz}"
        [ ! -f "$infile" ] && {
          echo "Error: invalid input file: $infile" >&2
          echo "Useage $0 [wp-dump.tar.gz]" >&2
          exit 1
        }

        TEMPDIR="$(mktemp -d)"
        mkdir -p "$TEMPDIR"
        cleanup() {
          sudo rm -rf "$TEMPDIR"
        }
        trap cleanup EXIT

        tar -xvzf "$infile" -C "$TEMPDIR"
        [ -f "$TEMPDIR/dump.sql" ] && {
          sudo mysql '${wp_dp_name}' < "$TEMPDIR/dump.sql"
        } || echo "Error: dump.sql not found in archive" >&2

        tempupdir="$TEMPDIR/$(basename '${wp_ups}')"
        [ -d "$tempupdir" ] && {
          sudo mkdir -p '${wp_ups}'
          sudo cp -rf "$tempupdir/"* '${wp_ups}'
          sudo chown -R ${wp_user}:${webgroup} "${wp_ups}"
          sudo chmod -R 750 "${wp_ups}"
          sudo find "${wp_ups}" -type f -exec sudo chmod 640 {} \;
        } || echo "Error: $(basename '${wp_ups}') directory not found in archive" >&2
      '');
    in [
      adjoin
      restoreWP
      get_wp_dump
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
        WPDUMP="$(realpath "$1" 2> /dev/null)"
        ADPASS="$2"
        echo "fixing nixos config permissions"
        sudo chown -R ${username}:users /home/${username}
        echo "joining AD"
        if [[ -z "$ADPASS" ]]; then
          ${adjoin}/bin/adjoin
        else
          ${adjoin}/bin/adjoin --stdin-password <<< "$ADPASS"
        fi
        ${restoreWP}/bin/restoreWP "$WPDUMP"
        ${genAdminSSHkey}/bin/genAdminSSHkey
        rm -f /home/${username}/.zsh_history
        echo "Initialization complete."
        echo "please reboot the machine to authenticate logins with AD"
      '')
    ];
  };

}
