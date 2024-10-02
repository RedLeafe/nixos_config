# NOTE:
# run the following to join AD:
# sudo adcli join --domain=your.domain.com --user=administrator
# source:
# https://www.reddit.com/r/NixOS/comments/1fin29x/successful_active_directory_client_example/

# TODO:
# test it
# It probably wont work.
# make it work.

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
      nameservers = lib.mkOption {
        default = [];
        type = listOf str;
        description = "IPs of AD nameservers";
      };
      # ADuser = lib.mkOption {
      #   default = "Administrator";
      #   type = str;
      #   description = "AD user to use for sudo adcli join -D command";
      # };
      # keyfile_path = lib.mkOption {
      #   default = "Administrator";
      #   type = str;
      #   description = "AD user to use for sudo adcli join -D command";
      # };
    };
  };

  config = lib.mkIf cfg.enable (let
    AD_D = lib.toUpper cfg.domain;
    ad_d = lib.toLower cfg.domain;
  in {

    # system.activationScripts.loginAD.text = ''
    #   sudo adcli join -D ${ad_d} --user=${cfg.aduser} --stdin-password <<< "$(cat '${cfg.keyfile_path}')"
    # '';

    networking.networkmanager.insertNameservers = lib.mkIf (cfg.nameservers != []) cfg.nameservers;

    services = {
      sssd = {
        enable = true;
        kcm = true;
        sshAuthorizedKeysIntegration = true;
        config = ''
          [sssd]
          domains = ${ad_d}
          config_file_version = 2
          services = nss, pam, sshd

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
          ldap_id_mapping = false
          auth_provider = ad
          access_provider = ad
          chpass_provider = ad
          ad_gpo_access_control = permissive
          enumerate = true
        '';
      };
    };

    security.pam.services.sshd.makeHomeDir = true;
    security.pam.services.sshd.startSession = true;

    security.pam.services.sssd.makeHomeDir = true;
    security.pam.services.sssd.startSession = true;

    security.pam.krb5.enable = true;

    security.krb5 = {
      enable = true;
      settings = {
        libdefaults = {
          udp_preference_limit = 0;
          default_realm = AD_D;
        };
      };
    };

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

    programs.oddjobd.enable = true;

    environment.systemPackages = with pkgs; [
      adcli         # Helper library and tools for Active Directory client operations
      oddjob        # Odd Job Daemon
      samba4Full    # Standard Windows interoperability suite of programs for Linux and Unix
      sssd          # System Security Services Daemon
      krb5          # MIT Kerberos 5
      # realmd        # DBus service for configuring Kerberos and other
    ];

  });
}
