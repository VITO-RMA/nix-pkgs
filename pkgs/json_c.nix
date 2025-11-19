{
  lib,
  stdenv,
  json_c,
  static ? stdenv.hostPlatform.isStatic,
}:

(json_c.override {
}).overrideAttrs
  (old: {
    doCheck = false;
    cmakeFlags = old.cmakeFlags or [ ] ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
  })
