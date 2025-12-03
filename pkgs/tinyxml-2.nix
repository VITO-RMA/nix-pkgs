{
  lib,
  stdenv,
  tinyxml-2,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(tinyxml-2.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    cmakeFlags = [
      "-DCMAKE_INSTALL_INCLUDEDIR=include"
      "-DCMAKE_INSTALL_LIBDIR=lib"
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    ];

    meta.platforms = lib.platforms.all;
  })
