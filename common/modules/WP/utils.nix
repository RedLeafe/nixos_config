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
    themeInputNames = builtins.filter
      (s: (builtins.match "WPthemes-.*" s) != null)
      (builtins.attrNames inputs);
    themeName = inputname:
      builtins.substring
        (builtins.stringLength "WPthemes-")
        (builtins.stringLength inputname)
        inputname;
    buildTheme = inputname: prev.stdenv.mkDerivation {
      name = themeName inputname;
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
    myWPthemes = builtins.listToAttrs (map
      (inputname: {
        name = themeName inputname;
        value = buildTheme inputname;
      })
      themeInputNames);
  });
}
