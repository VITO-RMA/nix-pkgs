{
  lib,
  stdenv,
  fetchFromGitHub,
  mcfgthreads,
  writeScriptBin,
  static ? stdenv.hostPlatform.isStatic,
}:

let
  dllTool = writeScriptBin "dlltool" ''
    ${stdenv.cc.targetPrefix}dlltool "$@"
  '';
in
mcfgthreads.overrideAttrs (old: rec {
  version = "2.1.1";
  src = fetchFromGitHub {
    owner = "lhmouse";
    repo = "mcfgthread";
    tag = "v${lib.versions.majorMinor version}-ga.${lib.versions.patch version}";
    hash = "sha256-kEqS1+2CB/Ryor2WbI67KALnlTcD9oSFEdC6Av73roE=";
  };

  mesonFlags =
    (old.mesonFlags or [ ])
    ++ lib.optionals static [
      "-Ddefault_library=static"
    ];

  postPatch = ''
    sed -z "s/Rules for tests.*//;s/'cpp'/'c'/g" -i meson.build
  '';

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = old.nativeBuildInputs ++ [
    dllTool
  ];

  postInstall =
    (old.postInstall or "")
    + lib.optionalString static ''
      rm -f $out/bin/libmcfgthread*.dll
      rm -f $out/lib/libmcfgthread*.dll.a
      rm -f $dev/lib/libmcfgthread*.dll.a
    '';
})
