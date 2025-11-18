{
  stdenv,
  zstd,
  static ? stdenv.hostPlatform.isStatic,
}:

(zstd.override {
  static = static;
})
