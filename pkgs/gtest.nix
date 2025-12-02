{
  lib,
  stdenv,
  gtest,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(gtest.override {
  static = static;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    cmakeFlags = old.cmakeFlags or [ ] ++ [
      "-DLZ4_BUILD_CLI=OFF"
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    ];
  })
