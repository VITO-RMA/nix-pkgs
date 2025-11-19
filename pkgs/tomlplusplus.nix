{
  stdenv,
  tomlplusplus,
  static ? stdenv.hostPlatform.isStatic,
}:

(tomlplusplus.override {
}).overrideAttrs
  (old: {
    doCheck = false;

    mesonFlags = old.mesonFlags
      ++ (if static then [ "-Ddefault_library=static" ] else [ "-Ddefault_library=shared" ]);
  })
