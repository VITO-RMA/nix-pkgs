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
    buildInputs = old.buildInputs or [ ] ++ [ zlib ];

    cmakeFlags = old.cmakeFlags or [ ] ++ lib.optionals static [ "-DLIBDEFLATE_BUILD_SHARED_LIB=OFF" ];
  })
