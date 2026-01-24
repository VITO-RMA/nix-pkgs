{
  static ? stdenv.hostPlatform.isStatic,
  stdenv,
  libxml2,
  zlib,
  libiconv,
  mkPackageName,
  ...
}:

(libxml2.override {
  enableStatic = static;
  enableShared = !static;
  zlibSupport = true;
  inherit libiconv;
  inherit zlib;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;
  })
