{
  lib,
  stdenv,
  geos,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(geos.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    cmakeFlags = old.cmakeFlags or [ ] ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];

    # Upstream hardcodes libstdc++ in geos.pc, but Darwin builds use libc++.
    postInstall = (old.postInstall or "") + lib.optionalString stdenv.hostPlatform.isDarwin ''
      substituteInPlace "$out/lib/pkgconfig/geos.pc" \
        --replace-fail "-lstdc++" "-lc++"
    '';
  })
