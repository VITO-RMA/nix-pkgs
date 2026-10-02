{
  lib,
  stdenv,
  fmt,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(fmt.override {
  enableShared = !static;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      (lib.cmakeBool "FMT_TEST" false)
    ];
  })
