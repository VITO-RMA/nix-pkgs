{
  lib,
  stdenv,
  zlib-ng,
  static ? stdenv.hostPlatform.isStatic,
  withZlibCompat ? false,
}:

(zlib-ng.override {
  withZlibCompat = withZlibCompat;
}).overrideAttrs
  (old: {
    dontDisableStatic = static;

    cmakeFlags =
      (old.cmakeFlags or [ ])
      ++ lib.optionals static [
        "-DBUILD_SHARED_LIBS=OFF"
      ];
  })
