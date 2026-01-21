{
  static ? stdenv.hostPlatform.isStatic,
  stdenv,
  libiconvReal,
  mkPackageName,
  ...
}:

(libiconvReal.override {
  enableStatic = static;
  enableShared = !static;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
  })
