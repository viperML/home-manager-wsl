{
  stdenvNoCC,
  python3Minimal,
}:
stdenvNoCC.mkDerivation rec {
  name = "analyze_path";
  propagatedBuildInputs = [
    python3Minimal
  ];
  dontBuild = true;
  dontUnpack = true;
  installPhase = ''
    install -Dm555 ${./. + "/${name}.py"} $out/bin/${name}
  '';
}
