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
  enableDarwinABICompat = stdenv.hostPlatform.isDarwin;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
  })
