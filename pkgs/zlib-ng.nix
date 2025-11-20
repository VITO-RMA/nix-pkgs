{
  lib,
  stdenv,
  zlib-ng,
  static ? stdenv.hostPlatform.isStatic,
  withZlibCompat ? false,
  mkPackageName,
}:

(zlib-ng.override {
  withZlibCompat = withZlibCompat;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    dontDisableStatic = static;

    cmakeFlags =
      (old.cmakeFlags or [ ])
      ++ lib.optionals static [
        (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
      ];
  })
