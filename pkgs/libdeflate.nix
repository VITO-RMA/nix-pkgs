{
  lib,
  stdenv,
  libdeflate,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(libdeflate.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;
    buildInputs = [ zlib ];

    cmakeFlags = old.cmakeFlags or [ ] ++ [ (lib.cmakeBool "LIBDEFLATE_BUILD_SHARED_LIB" (!static)) ];
  })
