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
  inherit libiconv;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;
  })
