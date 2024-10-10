{ config, pkgs, lib, modulesPath, inputs, stateVersion, username, hostname, system-modules, authorized_keys, nixpkgs, ... }: let
  git_server_home_dir = "/var/lib/git-server";
  sqldbpkg = config.services.mysql.package;
  dumpDBall = pkgs.writeShellScriptBin "dumpDBall" ''
    outfile="''${1:-/home/${username}/restored_data/dump.sql}"
    umask 077
    mkdir -p "$(dirname "$outfile")"
    if [ "$USER" == "root" ]; then
      ${sqldbpkg}/bin/mysqldump -u root --password="$2" --all-databases > "$outfile"
    else
      sudo ${sqldbpkg}/bin/mysqldump -u root --password="$2" --all-databases > "$outfile"
    fi
  '';
in {
  imports = with system-modules; [
    "${modulesPath}/virtualisation/vmware-guest.nix"
    ../vm.nix
    ./hardware-configuration.nix
    WP
    sshgit
  ];
  virtualisation.vmware.guest.enable = true;

  moon_mods.WP.enable = true;

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

  systemd = let
    servicename = "backup_runner";
    servicescript = pkgs.writeShellScript "backup_runner-script" ''
      export PATH="${lib.makeBinPath (with pkgs; [ bash sqldbpkg coreutils-full ])}:$PATH";
      umask 077
      if [ -e /home/${username}/restored_data ]; then
        mkdir -p /home/${username}/backupcache
        if [ -e /home/${username}/restored_data/dump.sql ]; then
          ${pkgs.zip}/bin/zip -9 /home/${username}/restored_data/dump.sql.zip /home/${username}/restored_data/dump.sql
          rm -f /home/${username}/restored_data/dump.sql
        fi
        files=( /home/${username}/backupcache/* )
        max=3
        for (( i=$((''${#files[@]}-1)); i>=0; i-- )); do
          file="''${files[$i]}"
          [ '/home/${username}/backupcache/*' == "$file" ] && break
          number="''${file##*[!0-9]}"
          base="''${file%%[0-9]*}"
          if [[ -n "$number" ]]; then
            incremented_number=$((number + 1))
          else
            incremented_number=1
          fi
          new_path="$base$incremented_number"
          if [ $incremented_number -gt $max ]; then
            rm -rf "$file"
          else
            mv "$file" "$new_path"
          fi
        done
        mv /home/${username}/restored_data /home/${username}/backupcache/restored_data1
      fi
      ${dumpDBall}/bin/dumpDBall
      ${dumpGitRepos}/bin/dumpGitRepos
      chown -R ${username}:users /home/${username}/restored_data
      chown -R ${username}:users /home/${username}/backupcache
    '';
  in {
    services.${servicename} = {
      description = "Run ${servicename}";
      serviceConfig = {
        ExecStart = "${pkgs.bash}/bin/bash ${servicescript}";
      };
    };
    timers."${servicename}-timer" = {
      description = "Timer to run ${servicename} every hour";
      timerConfig = {
        OnCalendar = "hourly";
        Persistent = true;
        Unit = "${servicename}.service";
      };
      wantedBy = [ "timers.target" ];
    };
  };

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
      restoreDBall = pkgs.writeShellScriptBin "restoreDBall" ''
        infile="''${1:-/home/${username}/restored_data/dump.sql}"
        if [ ! -e "$infile" ]; then
          echo "Error: $infile not found"
        else
          sudo ${sqldbpkg}/bin/mysql -u root --password="$2" < "$infile"
        fi
      '';
      yeet_trash = pkgs.writeShellScriptBin "yeet_trash" ''
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
    in [
      adjoin
      dumpDBall
      restoreDBall
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
        WPDBDUMP="$(realpath "$1" 2> /dev/null)"
        REPOZIP="$(realpath "$2" 2> /dev/null)"
        ADPASS="$3"
        echo "fixing nixos config permissions"
        sudo chown -R ${username}:users /home/${username}/nixos_config
        sudo chown -R ${username}:users /home/${username}/restored_data
        ${genAdminSSHkey}/bin/genAdminSSHkey
        echo "joining AD"
        if [[ -z "$ADPASS" ]]; then
          ${adjoin}/bin/adjoin
        else
          ${adjoin}/bin/adjoin --stdin-password <<< "$ADPASS"
        fi
        ${restoreDBall}/bin/restoreDBall "$WPDBDUMP"
        rm -f /home/${username}/.zsh_history
        echo "Initialization complete."
        echo "please reboot the machine to authenticate logins with AD"
      '')
    ];
  };

}
