{
  lib,
  stdenv,
  libxlsxwriter,
  minizip,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
}:

(libxlsxwriter.override { }).overrideAttrs (old: {
  doCheck = false;

  buildInputs = [
    minizip
    zlib
  ];

  cmakeFlags = old.cmakeFlags or [ ] ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
})
