{
  lib,
  stdenv,
  howard-hinnant-date,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(howard-hinnant-date.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    mingwSupport = false;
    doCheck = false;

    cmakeFlags = [
      "-DBUILD_TZ_LIB=ON"
      "-DUSE_SYSTEM_TZ_DB=ON"
    ]
    ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
  })
