importName: inputs: (final: prev: let
  pkgs = import inputs.nixpkgs { inherit (prev) system; };
in {
  ${importName} = pkgs.callPackage ./package.nix { };
})
