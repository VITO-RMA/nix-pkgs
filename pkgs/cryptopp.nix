{
  stdenv,
  cryptopp,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(cryptopp.override {
  enableStatic = static;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    # Fix mingw compilation
    NIX_CFLAGS_COMPILE =
      (old.NIX_CFLAGS_COMPILE or "")
      + (if stdenv.hostPlatform.isMinGW then " -D_WIN32_WINNT=0x0600" else "");
  })
