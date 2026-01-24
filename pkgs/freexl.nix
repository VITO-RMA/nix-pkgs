{
  lib,
  stdenv,
  freexl,
  expat,
  minizip,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  libiconv,
  mkPackageName,
}:

(freexl.override {
  inherit minizip;
  inherit libiconv;
  inherit zlib;
}).overrideAttrs
  (old: rec {
    pname = mkPackageName old.pname static stdenv;

    patches = [
      ./patches/freexl-dependencies.patch
    ];

    buildInputs = [
      zlib
      expat
      minizip
    ]
    ++ lib.optional (stdenv.hostPlatform.isWindows || stdenv.hostPlatform.isDarwin) libiconv;
    propagatedBuildInputs = buildInputs;

    doCheck = false;

    # FreeXL's configure script checks for unzLocateFile by linking with
    # -lminizip only. With static libminizip this can fail unless zlib is also
    # on the link line (minizip.pc: Libs.private: -lz).
    preConfigure =
      (old.preConfigure or "")
      + lib.optionalString static ''
        export LIBS="$LIBS -lz"
      '';

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
