{
  lib,
  stdenv,
  eigen,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(eigen.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    meta.platforms = lib.platforms.all;
  })
