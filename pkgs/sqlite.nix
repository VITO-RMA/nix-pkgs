{
  lib,
  stdenv,
  sqlite,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

sqlite.overrideAttrs (old: {
  pname = mkPackageName old.pname static stdenv;
  buildInputs = [ zlib ];

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
