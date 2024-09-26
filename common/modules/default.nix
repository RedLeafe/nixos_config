{ inputs, homeManager, ... }: let
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
in
{
  LD = import (systemOnly ./LD) { inherit moduleNamespace; };
  AD = import (systemOnly ./AD) { inherit moduleNamespace; };
  NFS = import (systemOnly ./NFS) { inherit moduleNamespace; };
  lightdm = import (systemOnly ./lightdm) { inherit moduleNamespace; };
  i3 = import (systemOnly ./i3) { inherit moduleNamespace; };
  thunar = import (homeOnly ./thunar) { inherit moduleNamespace; };
  ranger = import ./ranger { inherit moduleNamespace homeManager; };
  alacritty = import ./alacritty { inherit moduleNamespace homeManager; };
  shell = import ./shell { inherit moduleNamespace homeManager; };
}
