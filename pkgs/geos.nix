{
  stdenv,
  geos,
  static ? stdenv.hostPlatform.isStatic,
}:

(geos.override {
}).overrideAttrs
  (old: {
    doCheck = false;

    cmakeFlags =
      old.cmakeFlags or [ ]
      ++ (if static then [ "-DBUILD_SHARED_LIBS=OFF" ] else [ "-DBUILD_SHARED_LIBS=ON" ]);
  })
