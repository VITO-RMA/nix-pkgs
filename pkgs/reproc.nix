{
  lib,
  stdenv,
  reproc,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(reproc.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    cmakeFlags = [
      "-DCMAKE_INSTALL_LIBDIR=lib"
      "-DREPROC++=ON"
      "-DREPROC_TEST=OFF"
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    ];
  })
