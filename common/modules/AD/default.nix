# NOTE:
# run the following to join AD:
# sudo adcli join -U Administrator

{ moduleNamespace, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.AD;
in {
  options = {
    ${moduleNamespace}.AD = with lib.types; {
      enable = lib.mkEnableOption "AD stuff";
      domain = lib.mkOption {
        default = "AD.DOMAIN.COM";
        type = str;
        description = "AD.DOMAIN.COM";
      };
      domain_short = lib.mkOption {
        default = "AD";
        type = str;
        description = "AD";
      };
      domain_controller = lib.mkOption {
        default = "dc.ad.domain.com";
        type = str;
        description = "domain controller for AD";
      };
      ldap_search_base = lib.mkOption {
        default = "CN=Users,DC=example,DC=com";
        type = str;
        description = "ldap search base";
      };
      # ADuser = lib.mkOption {
      #   default = "Administrator";
      #   type = str;
      #   description = "AD user to use for adcli join command";
      # };
      # keyfile_path = lib.mkOption {
      #   default = "/tmp/ADprovisionPass";
      #   type = str;
      #   description = "path containing the ADuser's password";
      # };
    };
  };

  config = lib.mkIf cfg.enable (let
    AD_D = lib.toUpper cfg.domain;
    ad_d = lib.toLower cfg.domain;
    AD_S = lib.toUpper cfg.domain_short;
    ad_s = lib.toLower cfg.domain_short;
  in {

    # system.activationScripts.loginAD.text = ''
    #   ${pkgs.adcli}/bin/adcli join -D ${ad_d} -U ${cfg.aduser} --stdin-password <<< "$(cat '${cfg.keyfile_path}')"
    # '';

    services = {
      sssd = {
        enable = true;
        kcm = true;
        sshAuthorizedKeysIntegration = true;
        config = ''
          [sssd]
          domains = ${ad_d}
          config_file_version = 2
          services = nss, pam, ssh

          [nss]

          [pam]

          [domain/${ad_d}]
          # default_shell = ${pkgs.zsh}/bin/zsh
          # shell_fallback = ${pkgs.zsh}/bin/zsh
          override_shell = ${pkgs.zsh}/bin/zsh
          krb5_store_password_if_offline = True
          cache_credentials = True
          krb5_realm = ${AD_D}
          # realmd_tags = manages-system joined-with-samba
          id_provider = ad
          override_homedir = /home/%u
          # fallback_homedir = /Users/%u
          ad_domain = ${ad_d}
          use_fully_qualified_names = false
          ldap_id_mapping = true
          auth_provider = ad
          access_provider = ad
          chpass_provider = ad
          ad_gpo_access_control = permissive
          enumerate = true
        '';
      };
    };

    users.ldap.server = "ldap://${cfg.domain_controller}/";
    users.ldap.daemon.enable = true;
    users.ldap.enable = true;
    users.ldap.nsswitch = true;
    users.ldap.useTLS = true;
    users.ldap.loginPam = true;
    users.ldap.base = cfg.ldap_search_base;

    security.pam.services.sshd.makeHomeDir = true;
    security.pam.services.sshd.startSession = true;

    security.pam.services.sssd.makeHomeDir = true;
    security.pam.services.sssd.startSession = true;

    security.pam.krb5.enable = true;

    programs.oddjobd.enable = true;

    security.krb5 = {
      enable = true;
      settings = {
        libdefaults = {
          udp_preference_limit = 0;
          default_realm = AD_D;
        };
        realms = {
          "${AD_D}" = {
            admin_server = cfg.domain_controller;
            default_domain = ad_d;
            kdc = [ cfg.domain_controller ];
          };
        };
      };
    };

    systemd.services.samba-smbd.enable = lib.mkDefault false;
    services.samba = {
      enable = true;
      nmbd.enable = lib.mkDefault false;
      winbindd.enable = lib.mkDefault false;
      package = pkgs.samba4Full;
      settings = {
        global = {
          security = "ads";
          realm = AD_D;
          workgroup = AD_S;
          "password server" = AD_D;
          "client use spnego" = "yes";
          "client signing" = "yes";
          "kerberos method" = "secrets and keytab";
        };
      };
    };

    environment.systemPackages = with pkgs; [
      adcli         # Helper library and tools for Active Directory client operations
      oddjob        # Odd Job Daemon
      sambaFull    # Standard Windows interoperability suite of programs for Linux and Unix
      sssd          # System Security Services Daemon
      krb5          # MIT Kerberos 5
      # realmd  # DBus service for configuring Kerberos and other
    ];

    # realmd relies on many static paths to programs.
    # while that is not super hard to fix,
    # at runtime, realmd changes config files.
    # those config files are provisioned by nix.
    # Thus, realmd cant change them.
    # Thus, making realmd run without errors is mostly a pointless exercise.
    # systemd.services.realmd = {
    #   description = "Realm Discovery Service";
    #   wantedBy = [ "multi-user.target" ];
    #   after = [ "network.target" ];
    #   serviceConfig = {
    #     Type = "dbus";
    #     BusName = "org.freedesktop.realmd";
    #     ExecStart = "${pkgs.realmd}/libexec/realmd";
    #     User = "root";
    #   };
    # };

  });
}
