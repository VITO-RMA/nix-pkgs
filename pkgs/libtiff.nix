{
  lib,
  stdenv,
  libtiff,
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
    buildInputs = (old.buildInputs or [ ]) ++ [
      zlib
      zstd
      xz
    ];

    patches = old.patches ++ [
      ./patches/libtiff-static-targets.patch
    ];

    outputs = builtins.filter (o: !(o == "doc" || o == "man")) (old.outputs or [ "out" ]);

    cmakeFlags =
      (old.cmakeFlags or [ ])
      ++ [
        "-Dtiff-docs=OFF"
        "-Dtiff-contrib=OFF"
        "-Dtiff-tests=OFF"
        "-Djbig=OFF"
        "-Djpeg=OFF"
        "-Djpeg12=OFF"
        "-Dwebp=OFF"
        "-Dzip=OFF"
        "-DCMAKE_DISABLE_FIND_PACKAGE_OpenGL=ON"
        "-DCMAKE_DISABLE_FIND_PACKAGE_GLUT=ON"
        "-DZSTD_HAVE_DECOMPRESS_STREAM=ON"
        "-DHAVE_JPEGTURBO_DUAL_MODE_8_12=OFF"
        "-DBUILD_DOC=OFF"
      ]
      ++ lib.optionals static [
        "-DBUILD_SHARED_LIBS=OFF"
      ];
  })
