{
  stdenv,
  boost,
  zlib,
  zstd,
  xz,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(boost.override {
  inherit zlib zstd xz;
  enableIcu = false;
  enablePython = false;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
  })
