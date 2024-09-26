{
  pkgs,
  lib,
  writeText,
  stdenv,
  bash,
  importName,
  inputs,
  ...
}:
let
in
stdenv.makeDerivation {
  name = importName;
  buildPhase = ''
    runHook preBuild
    mkdir -p $out/bin
    cat > $out/bin/${importName} <<EOFTAG
    #!${bash}
    echo "hello and welcome to the ${importName} package!"
    EOFTAG
    chmod +x $out/bin/${importName}
    runHook postBuild
  '';
}
