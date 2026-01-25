{
  stdenv,
  brotli,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(brotli.override {
  staticOnly = static;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;
  })
