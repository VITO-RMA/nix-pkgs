{
  stdenv,
  json_c,
  static ? stdenv.hostPlatform.isStatic,
}:

(json_c.override {
}).overrideAttrs
  (old: {
    doCheck = false;
    cmakeFlags =
      old.cmakeFlags or [ ]
      ++ (if static then [ "-DBUILD_SHARED_LIBS=OFF" ] else [ "-DBUILD_SHARED_LIBS=ON" ]);
  })
