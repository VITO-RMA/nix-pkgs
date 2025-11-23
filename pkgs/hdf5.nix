{
  lib,
  stdenv,
  hdf5,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(hdf5.override {
  enableStatic = static;
  enableShared = !static;
}).overrideAttrs
  (old: rec {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    buildInputs = [ zlib ];
    propagatedBuildInputs = buildInputs;
    meta.platforms = lib.platforms.all;
  })
