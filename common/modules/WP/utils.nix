{
  mkplugs = inputs: (final: prev: let
    plugInputNames = builtins.filter
      (s: (builtins.match "WPplugins-.*" s) != null)
      (builtins.attrNames inputs);
    plugName = inputname:
      builtins.substring
        (builtins.stringLength "WPplugins-")
        (builtins.stringLength inputname)
        inputname;
    buildPlug = inputname: prev.stdenv.mkDerivation {
      name = plugName inputname;
      src = builtins.getAttr inputname inputs;
      installPhase = "mkdir -p $out; cp -R * $out/";
    };
  in
  {
    myWPext = builtins.listToAttrs (map
      (inputname: {
        name = plugName inputname;
        value = buildPlug inputname;
      })
      plugInputNames);
  });
}
