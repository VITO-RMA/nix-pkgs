{
  lib,
  stdenv,
  json_c,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(json_c.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;
    cmakeFlags = old.cmakeFlags or [ ] ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
    meta = old.meta // {
      platforms = lib.platforms.all;
    };
  })
