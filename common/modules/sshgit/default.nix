
{ moduleNamespace, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.sshgit;

  mkNewGitShell = { xtras ? {}, git, stdenv, writeShellScript, writeShellScriptBin, lib, ... }: let
    extracmds = builtins.mapAttrs (name: value: writeShellScriptBin name value) xtras;
    cmds = builtins.concatStringsSep " " (builtins.map lib.escapeShellArg (builtins.attrNames extracmds));
    path = lib.makeBinPath ([ git ] ++ (builtins.attrValues extracmds));
    new-git-shell = writeShellScript "new-git-shell" ''
      cmd="$1"
      export PATH="${path}"
      [ -z "$cmd" ] && exec git-shell
      found=false
      for xtra in ${cmds}; do
        [ "$xtra" == "$cmd" ] && found=true && break
      done
      [ $found ] && exec "$@"
      [ ! $found ] && exec git-shell -c "$*"
    '';
  in stdenv.mkDerivation {
    name = "new-git-shell";
    src = new-git-shell;
    passthru.shellPath = "/bin/new-git-shell";
    buildPhase = ''
      mkdir -p $out/bin
      cp $src $out/bin/new-git-shell
    '';
  };

in {
  options = {
    ${moduleNamespace}.sshgit = with lib; {
      enable = mkEnableOption "sshd and git stuff";
      AD_support = mkEnableOption "ssh Active Directory support";
      authorized_keys = mkOption {
        default = [];
        type = types.listOf types.str;
      };
      settings = mkOption {
        default = {};
        type = types.raw;
        description = "maps to services.openssh.settings";
      };
      fail2ban = mkEnableOption "enable fail2ban";
      git_shell_scripts = mkOption {
        default = {};
        type = types.attrsOf types.str;
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

    users.users.git = let
      git = config.programs.git.package;
      git-home = cfg.git_home_dir;
      default_git_shell_xtras = {
        new-remote = /*bash*/''
          export PATH="$PATH:${pkgs.coreutils}/bin"
          logfile="${git-home}/creation_logs.txt"
          for name in "$@"; do
            echo "$(date): attempting to create repo: $name.git" | tee -a "$logfile"
            repo_path="${git-home}/$name.git"
            if [ -e "$repo_path" ]; then
              echo "$(date): File already exists, skipping: $name.git" | tee -a "$logfile"
            else
              mkdir -p "$repo_path"
              if ${git}/bin/git init --bare "$repo_path" 2>&1 | tee -a "$logfile"; then
                echo "$(date): Created repo: git@PUT_HOST_HERE:$name.git" | tee -a "$logfile"
              else
                echo "$(date): failed to create repo: $name.git" | tee -a "$logfile"
              fi
            fi
          done
        '';
      };
      final_git_shell_scripts = default_git_shell_xtras // cfg.git_shell_scripts;
      new-git-shell = pkgs.callPackage mkNewGitShell {
        xtras = final_git_shell_scripts;
        inherit git;
      };
    in {
      isSystemUser = true;
      group = "git";
      home = git-home;
      createHome = true;
      shell = new-git-shell;
      openssh.authorizedKeys.keys = cfg.authorized_keys;
      packages = [ new-git-shell ];
    };

    users.groups.git = {};

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
      '') + ''
        Match user git
          AllowTcpForwarding no
          AllowAgentForwarding no
          PasswordAuthentication no
          PermitTTY no
          X11Forwarding no
      '' + cfg.extraSSHDconfig;
    };
  };
}
