{
  stdenv,
  howard-hinnant-date,
  static ? stdenv.hostPlatform.isStatic,
}:

(howard-hinnant-date.override {
}).overrideAttrs
  (old: {
    doCheck = false;

    cmakeFlags = [
      "-DBUILD_TZ_LIB=ON"
      "-DUSE_SYSTEM_TZ_DB=ON"
    ]
    ++ (if static then [ "-DBUILD_SHARED_LIBS=OFF" ] else [ "-DBUILD_SHARED_LIBS=ON" ]);
  })
