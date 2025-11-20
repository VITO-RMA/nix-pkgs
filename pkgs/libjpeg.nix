{
  stdenv,
  libjpeg,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(libjpeg.override {
  enableShared = !static;
  enableStatic = static;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
  })
