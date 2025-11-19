{
  lib,
  stdenv,
  geos,
  static ? stdenv.hostPlatform.isStatic,
}:

(geos.override {
}).overrideAttrs
  (old: {
    doCheck = false;

    cmakeFlags = old.cmakeFlags or [ ] ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
  })
