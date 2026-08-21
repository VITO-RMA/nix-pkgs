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
  enableShared = !static;
  enableStatic = static;
  extraB2Args = if (stdenv.cc.isZig or false) then [ "pch=off" ] else [ ];
  toolset =
    if (stdenv.cc.isZig or false) then
      "clang"
    else if stdenv.cc.isClang then
      "clang"
    else if stdenv.cc.isGNU then
      "gcc"
    else
      null;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
  })
