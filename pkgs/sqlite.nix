{
  lib,
  stdenv,
  sqlite,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

sqlite.overrideAttrs (old: rec {
  pname = mkPackageName old.pname static stdenv;
  buildInputs = [ zlib ];
  propagatedBuildInputs = buildInputs;

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
