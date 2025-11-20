{
  lib,
  stdenv,
  vc,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(vc.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    cmakeFlags =
      old.cmakeFlags or [ ]
      ++ [
        "-DBUILD_TESTING=OFF"
        "-DBUILD_EXAMPLES=OFF"
      ]
      ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
  })
