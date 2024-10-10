{ inputs, ... }:
{ homeManager ? false, nixos ? false, keys ? false, overlaysList ? false, ... }:
let
  inherit (inputs.nixpkgs) lib;
  keys_from_path = keypath: builtins.attrValues (builtins.mapAttrs (n: v:
      if v == "regular"
        then builtins.replaceStrings ["\r" "\n"] ["" ""] (builtins.readFile "${keypath}/${n}")
        else "")
      (builtins.readDir "${keypath}")
    );
  nixosMods = import ./modules { inherit inputs; homeManager = false; };
  homeMods = import ./modules { inherit inputs; homeManager = true; };
  overs = import ./overlays inputs;
  auth_keys = keys_from_path ./auth_keys;
in {
  home-modules = lib.optionalAttrs homeManager homeMods;
  system-modules = lib.optionalAttrs nixos nixosMods;
  overlays = lib.optionals overlaysList overs;
  authorized_keys = lib.optionals keys auth_keys;
}
