{
  lib,
  stdenv,
  freexl,
  expat,
  minizip,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  libiconv,
  mkPackageName,
  cmake,
  pkg-config,
}:

(freexl.override {
  inherit minizip;
  inherit libiconv;
  inherit zlib;
}).overrideAttrs
  (old: rec {
    pname = mkPackageName old.pname static stdenv;

    nativeBuildInputs = [
      cmake
      pkg-config
    ];

    buildInputs = [
      zlib
      expat
      minizip
    ]
    ++ lib.optional (stdenv.hostPlatform.isWindows || stdenv.hostPlatform.isDarwin) libiconv;
    propagatedBuildInputs = buildInputs;

    # Drop autotools patches — we use our own CMakeLists.txt
    patches = [ ];

    # Replace the autotools build with our cmake-based one
    postPatch = ''
      mkdir -p cmake
      cp ${./patches/freexl/CMakeLists.txt} CMakeLists.txt
      cp ${./patches/freexl/config.h.in} cmake/config.h.in
      cp ${./patches/freexl/freexl.pc.in} cmake/freexl.pc.in
    '';

    cmakeFlags = [
      "-DFREEXL_ENABLE_XMLDOC=ON"
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    ];

    # Clear autotools-specific attributes
    configureFlags = [ ];
    preConfigure = "";

    doCheck = false;

    meta = old.meta // {
      platforms = lib.platforms.all;
    };
  })
