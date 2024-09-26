importName: inputs: let
  overlay = self: super: { 
    ${importName} = self.callPackage ./package.nix { inherit inputs importName; };
  };
in
overlay
