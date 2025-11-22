{
  lib,
  stdenv,
  doctest,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(doctest.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    cmakeFlags = old.cmakeFlags or [ ] ++ [
      "-DDOCTEST_WITH_TESTS=OFF"
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    ];
  })
