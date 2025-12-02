{
  lib,
  stdenv,
  shapelib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

shapelib.overrideAttrs (old: {
  pname = mkPackageName old.pname static stdenv;
  doCheck = false;

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
