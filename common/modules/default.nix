{ inputs, homeManager ? false, ... }: let
  homeOnly = path:
    (if homeManager
      then path
      else builtins.throw "no system module with that name"
    );
  systemOnly = path:
    (if homeManager
      then builtins.throw "no home-manager module with that name"
      else path
    );
  moduleNamespace = "moon_mods";
  args = { inherit moduleNamespace inputs homeManager; };
in
{
  LD = import (systemOnly ./LD) args;
  WP = import (systemOnly ./WP) args;
  AD = import (systemOnly ./AD) args;
  sshgit = import (systemOnly ./sshgit) args;
  xtermwm = import (systemOnly ./xtermwm) args;
  ranger = import ./ranger args;
  shell = import ./shell args;
  gitea = import ./gitea args;
}
