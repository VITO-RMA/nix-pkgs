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
  mkPackageName,
}:
(libtiff.override {
}).overrideAttrs
  (old: rec {
    pname = mkPackageName old.pname static stdenv;
    dontDisableStatic = static;

    doCheck = false;
    buildInputs = [
      lerc
      libdeflate
      zlib
      xz
      zstd
    ];
    propagatedBuildInputs = buildInputs;

    patches = old.patches ++ [
      ./patches/libtiff-static-targets.patch
    ];

    postPatch = (old.postPatch or "") + ''
      # On case-insensitive Darwin filesystems this shadows CMake's FindLibLZMA
      # module, but defines liblzma::liblzma instead of LibLZMA::LibLZMA.
      rm cmake/Findliblzma.cmake
    '';

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
        "-DCMAKE_REQUIRE_FIND_PACKAGE_LibLZMA=ON"
        "-DZSTD_HAVE_DECOMPRESS_STREAM=ON"
        "-DHAVE_JPEGTURBO_DUAL_MODE_8_12=OFF"
        "-DBUILD_DOC=OFF"
      ]
      ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
  })
