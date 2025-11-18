{
  static ? stdenv.hostPlatform.isStatic,
  stdenv,
  xz,
  ...
}:

(xz.override {
  enableStatic = static;
}).overrideAttrs
  (old: {
    doCheck = false;
  })
