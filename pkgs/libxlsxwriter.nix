{
  stdenv,
  libxlsxwriter,
  minizip,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
}:

(libxlsxwriter.override {
}).overrideAttrs
  (old: {
    doCheck = false;

    cmakeFlags =
      old.cmakeFlags or [ ]
      ++ [ "-DLZ4_BUILD_CLI=OFF" ]
      ++ (if static then [ "-DBUILD_SHARED_LIBS=OFF" ] else [ "-DBUILD_SHARED_LIBS=ON" ]);
  })
