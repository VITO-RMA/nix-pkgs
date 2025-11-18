{
  stdenv,
  lz4,
  static ? stdenv.hostPlatform.isStatic,
}:

(lz4.override {
}).overrideAttrs
  (old: {
    doCheck = false;

    cmakeFlags =
      old.cmakeFlags or [ ]
      ++ [ "-DLZ4_BUILD_CLI=OFF" ]
      ++ (if static then [ "-DBUILD_SHARED_LIBS=OFF" ] else [ "-DBUILD_SHARED_LIBS=ON" ]);
  })
