{
  lib,
  stdenv,
  libwebp,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(libwebp.override {
  openglSupport = false;
  pngSupport = false;
  jpegSupport = false;
  tiffSupport = false;
  gifSupport = false;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
      (lib.cmakeBool "WEBP_BUILD_CWEBP" false)
      (lib.cmakeBool "WEBP_BUILD_DWEBP" false)
      (lib.cmakeBool "WEBP_BUILD_WEBPINFO" false)
      (lib.cmakeBool "WEBP_BUILD_WEBPMUX" false)
    ];
  })
