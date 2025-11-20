{
  lib,
  stdenv,
  lz4,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(lz4.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    cmakeFlags =
      old.cmakeFlags or [ ]
      ++ [ "-DLZ4_BUILD_CLI=OFF" ]
      ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
  })
