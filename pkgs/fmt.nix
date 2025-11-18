{
  stdenv,
  fmt,
  static ? stdenv.hostPlatform.isStatic,
}:

(fmt.override {
  enableShared = !static;
}).overrideAttrs
  (old: {
    doCheck = false;
  })
