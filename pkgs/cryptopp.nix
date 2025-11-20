{
  stdenv,
  cryptopp,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(cryptopp.override {
  enableStatic = static;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;
    mingwSupport = false;
  })
