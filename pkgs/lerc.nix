{
  lib,
  stdenv,
  lerc,
  static ? stdenv.hostPlatform.isStatic,
}:

(lerc.override {
}).overrideAttrs
  (old: {
    doCheck = false;

    cmakeFlags = old.cmakeFlags or [ ] ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
  })
