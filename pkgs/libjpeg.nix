{
  stdenv,
  libjpeg,
  static ? stdenv.hostPlatform.isStatic,
}:

(libjpeg.override {
  enableShared = !static;
  enableStatic = static;
})
