{
  stdenv,
  cryptopp,
  static ? stdenv.hostPlatform.isStatic,
}:

(cryptopp.override {
  enableStatic = static;
}).overrideAttrs
  (old: {
    doCheck = false;
  })
