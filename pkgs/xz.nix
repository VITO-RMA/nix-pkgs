{
  static ? stdenv.hostPlatform.isStatic,
  stdenv,
  xz,
  mkPackageName,
  ...
}:

(xz.override {
  enableStatic = static;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;
  })
