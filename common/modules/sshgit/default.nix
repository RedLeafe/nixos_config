{ moduleNamespace, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.sshgit;
in {
  options = {
    ${moduleNamespace}.sshgit = with lib; {
      enable = mkEnableOption "sshd and git stuff";
      AD_support = mkEnableOption "ssh Active Directory support";
      fail2ban = mkEnableOption "enable fail2ban";
      enable_git_server = mkEnableOption "sshd and git stuff";
      authorized_keys = mkOption {
        default = [];
        type = types.listOf types.str;
      };
      settings = mkOption {
        default = {};
        type = types.raw;
        description = "maps to services.openssh.settings";
      };
      git_shell_scripts = mkOption {
        default = {};
        type = types.attrsOf types.str;
      };
      default_git_user = mkOption {
        default = "user";
        type = types.str;
      };
      default_git_email = mkOption {
        default = "user@email.com";
        type = types.str;
      };
      repo_clone_hostname = mkOption {
        default = "0.0.0.0";
        type = types.str;
      };
      git_home_dir = mkOption {
        default = "/var/lib/git-server";
        type = types.str;
      };
      extraSSHDconfig = mkOption {
        default = "";
        type = types.str;
        description = "maps to services.openssh.extraConfig";
      };
    };
  };
  config = lib.mkIf cfg.enable {

    programs.git = {
      enable = true;
      config = {
        core.fsmonitor = true;
        init.defaultBranch = "master";
        user.email = cfg.default_git_email;
        user.name = cfg.default_git_user;
      };
    };

    users.users.git = lib.mkIf cfg.enable_git_server {
      isSystemUser = true;
      group = "git";
      home = cfg.git_home_dir;
      createHome = true;
      shell = "${config.programs.git.package}/bin/git-shell";
      openssh.authorizedKeys.keys = cfg.authorized_keys;
    };

    users.groups.git = lib.mkIf cfg.enable_git_server {};

    services.fail2ban.enable = true;

    programs.ssh.package = if cfg.AD_support then pkgs.opensshWithKerberos else pkgs.openssh;

    services.openssh = {
      enable = true;
      ports = [ 22 ];
      package = if cfg.AD_support then pkgs.opensshWithKerberos else pkgs.openssh;
      settings = cfg.settings;
      extraConfig = (lib.optionalString (cfg.AD_support) ''
        KerberosAuthentication yes
        KerberosOrLocalPasswd yes
        GSSAPIAuthentication yes
        GSSAPICleanupCredentials yes
      '') + (lib.optionalString (cfg.enable_git_server) ''
        Match user git
          AllowTcpForwarding no
          AllowAgentForwarding no
          PasswordAuthentication no
          PermitTTY no
          X11Forwarding no
      '') + cfg.extraSSHDconfig;
    };

    system.activationScripts.git_shell_scripts.text = lib.optionalString ((config.users.users ? git) && cfg.enable_git_server) (let
      mkNewGitShellCmds = { xtras ? {}, symlinkJoin, writeTextFile, ... }: let
        extracmds = builtins.attrValues (builtins.mapAttrs (name: value: writeTextFile {
          inherit name;
          text = value;
          executable = true;
          destination = "/git-shell-commands/" + name;
        }) xtras);
      in symlinkJoin {
        name = "git-shell-commands";
        paths = extracmds;
      };

      default_git_shell_xtras = (let
        git-home = config.users.users.git.home;
      in {
        new-remote = /*bash*/''
          #!${pkgs.bash}/bin/bash
          export PATH="$PATH:${lib.makeBinPath (with pkgs; [ coreutils ])}"
          logfile="${git-home}/creation_logs.txt"
          umask 007
          is_safe_path () {
            local repo_path="$(realpath "$1")"
            # 1 == false; 0 == true
            [ -e "$repo_path" ] && return 1 # Path exists
            [[ "$repo_path" != "${git-home}/"* ]] && return 1 # Path is outside of git-home
            return 0 # all cases passed
          }
          for name in "$@"; do
            echo "$(date): attempting to create repo: $name.git" | tee -a "$logfile"
            repo_path="${git-home}/$name.git"
            if ! is_safe_path "$repo_path"; then
              echo "$(date): Bad file path, skipping: $name.git" | tee -a "$logfile"
            else
              mkdir -p "$repo_path"
              if ${config.programs.git.package}/bin/git init --bare "$repo_path" 2>&1 | tee -a "$logfile"; then
                echo "$(date): Created repo: git@${cfg.repo_clone_hostname}:$name.git" | tee -a "$logfile"
              else
                echo "$(date): failed to create repo: $name.git" | tee -a "$logfile"
              fi
            fi
          done
        '';
      });
      final_git_shell_scripts = default_git_shell_xtras // cfg.git_shell_scripts;
      custom_git_commands = pkgs.callPackage mkNewGitShellCmds {
        xtras = final_git_shell_scripts;
      };
    in ''
      ln -sf ${custom_git_commands}/git-shell-commands ${config.users.users.git.home}
    '');
  };
}
