{
  lib,
  stdenv,
  minizip,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:
minizip.overrideAttrs (old: rec {
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

  meta = old.meta // {
    platforms = lib.platforms.all;
  };
})
