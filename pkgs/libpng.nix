{
  lib,
  stdenv,
  libpng,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

libpng.overrideAttrs (old: rec {
  pname = mkPackageName old.pname static stdenv;
  buildInputs = [ zlib ];
  propagatedBuildInputs = buildInputs;

  doCheck = false;

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
