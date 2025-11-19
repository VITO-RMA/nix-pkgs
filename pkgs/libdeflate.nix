{
  lib,
  stdenv,
  libdeflate,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
}:

(libdeflate.override {
}).overrideAttrs
  (old: {
    doCheck = false;
    buildInputs = [ zlib ];

    cmakeFlags = old.cmakeFlags or [ ] ++ [ (lib.cmakeBool "LIBDEFLATE_BUILD_SHARED_LIB" (!static)) ];
  })
