{
  lib,
  stdenv,
  icu,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(icu.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;

    doCheck = false;
    withStatic = static;
    dontDisableStatic = static;

    patches =
      old.patches or [ ]
      ++ lib.optionals static [
        ./patches/icu-disable-static-prefix.patch
        ./patches/icu-mingw-dll-install.patch
      ];

    configureFlags =
      (old.configureFlags or [ ])
      ++ lib.optionals static [
        "--enable-static"
        "--disable-shared"
      ];
  })
