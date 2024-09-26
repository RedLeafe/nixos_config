{ moduleNamespace, ... }: # <- a function
# that returns a module
{ config, pkgs, lib, ... }: let
  cfg = config.${moduleNamespace}.NFS;
in {
  # TODO: Do we need/want this?
  options = {
    ${moduleNamespace}.NFS = with lib.types; {
      enable = lib.mkEnableOption "NFS stuff";
      mounts = lib.mkOption {
        default = [];
        description = ''
          List of NFS mounts

          mounts = [
            { what = "myfileserver:/home/jdoe"; where = "/home/jdoe"; }
            { what = "myfileserver:/nfs/archive"; where = "/nfs/archive"; }
          ];
        '';
        type = listOf (submodule {
          options = {
            what = lib.mkOption {
              type = str;
            };
            where = lib.mkOption {
              type = str;
            };
          };
        });
      };
    };
  };

  config = lib.mkIf cfg.enable (let
  in {
    systemd = let
      commonMountOptions = {
        type = "nfs";
        mountConfig.Options = "noatime";
      };
      commonAutoMountOptions = {
        wantedBy = [ "multi-user.target" ];
        automountConfig.TimeoutIdleSec = "600";
      };
      mounts = cfg.mounts;
    in {
      mounts = map (mount: commonMountOptions // mount) mounts;
      automounts = map (mount: commonAutoMountOptions // { inherit (mount) where; }) mounts;
    };
  });
}
