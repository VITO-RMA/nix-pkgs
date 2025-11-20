{
  stdenv,
  tomlplusplus,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(tomlplusplus.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    mesonFlags =
      old.mesonFlags
      ++ (if static then [ "-Ddefault_library=static" ] else [ "-Ddefault_library=shared" ]);
  })
