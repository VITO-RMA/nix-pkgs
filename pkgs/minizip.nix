{
  lib,
  stdenv,
  minizip,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

minizip.overrideAttrs (old: {
  pname = mkPackageName old.pname static stdenv;
  buildInputs = [ zlib ];
  doCheck = false;

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
