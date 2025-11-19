{
  lib,
  stdenv,
  lerc,
  libtiff,
  libdeflate,
  zlib,
  xz,
  zstd,
  static ? stdenv.hostPlatform.isStatic,
}:

(libtiff.override {
}).overrideAttrs
  (old: {
    dontDisableStatic = static;

    doCheck = false;
    buildInputs = [
      lerc
      libdeflate
      zlib
      xz
      zstd
    ];

    patches = old.patches ++ [
      ./patches/libtiff-static-targets.patch
    ];

    outputs = builtins.filter (o: !(o == "doc" || o == "man" || o == "bin")) (old.outputs or [ "out" ]);

    cmakeFlags =
      (old.cmakeFlags or [ ])
      ++ [
        "-Dtiff-docs=OFF"
        "-Dtiff-contrib=OFF"
        "-Dtiff-tests=OFF"
        "-Dtiff-tools=OFF"
        "-Djbig=OFF"
        "-Djpeg=OFF"
        "-Djpeg12=OFF"
        "-Dwebp=OFF"
        "-Dzip=OFF"
        "-DCMAKE_DISABLE_FIND_PACKAGE_OpenGL=ON"
        "-DCMAKE_DISABLE_FIND_PACKAGE_GLUT=ON"
        "-DCMAKE_DISABLE_FIND_PACKAGE_LibLZMA=ON"
        "-DZSTD_HAVE_DECOMPRESS_STREAM=ON"
        "-DHAVE_JPEGTURBO_DUAL_MODE_8_12=OFF"
        "-DBUILD_DOC=OFF"
        "-DLERC_INCLUDE_DIRS=${lib.getDev lerc}/include"
        "-DLERC_LIBRARY_RELEASE=${lib.getLib lerc}/lib/libLerc${
          if static then
            stdenv.hostPlatform.extensions.staticLibrary
          else
            stdenv.hostPlatform.extensions.sharedLibrary
        }"
        "-DZSTD_INCLUDE_DIRS=${lib.getDev zstd}/include"
        "-DZSTD_LIBRARY_RELEASE=${lib.getLib zstd}/lib/libzstd${
          if static then
            stdenv.hostPlatform.extensions.staticLibrary
          else
            stdenv.hostPlatform.extensions.sharedLibrary
        }"
      ]
      ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
  })
