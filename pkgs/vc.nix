{
  lib,
  stdenv,
  vc,
  static ? stdenv.hostPlatform.isStatic,
}:

(vc.override {
}).overrideAttrs
  (old: {
    doCheck = false;

    cmakeFlags =
      old.cmakeFlags or [ ]
      ++ [
        "-DBUILD_TESTING=OFF"
        "-DBUILD_EXAMPLES=OFF"
      ]
      ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
  })
