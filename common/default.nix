{ inputs, ... }:
{ homeManager ? false, nixos ? false, overlaysList ? false, ... }:
let
  inherit (inputs.nixpkgs) lib;
  nixosMods = import ./modules { inherit inputs; homeManager = false; };
  homeMods = import ./modules { inherit inputs; homeManager = true; };
  overs = import ./overlays inputs;
in {
  home-modules = lib.optionalAttrs homeManager homeMods;
  system-modules = lib.optionalAttrs nixos nixosMods;
  overlays = lib.optionals overlaysList overs;
}
