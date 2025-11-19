{
  lib,
  stdenv,
  lz4,
  static ? stdenv.hostPlatform.isStatic,
}:

(lz4.override {
}).overrideAttrs
  (old: {
    doCheck = false;

    cmakeFlags =
      old.cmakeFlags or [ ]
      ++ [ "-DLZ4_BUILD_CLI=OFF" ]
      ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
  })
