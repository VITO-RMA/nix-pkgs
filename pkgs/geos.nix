{
  lib,
  stdenv,
  geos,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(geos.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    cmakeFlags = old.cmakeFlags or [ ] ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
  })
