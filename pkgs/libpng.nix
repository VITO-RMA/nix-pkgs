{
  lib,
  stdenv,
  libpng,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

libpng.overrideAttrs (old: {
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
