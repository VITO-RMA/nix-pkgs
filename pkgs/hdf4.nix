{
  lib,
  stdenv,
  hdf4,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  libjpeg,
  zlib,
  fortranSupport ? false,
  netcdfSupport ? false,
}:

(hdf4.override {
  # Match upstream override arg casing (nixpkgs pkgs/by-name/hd/hdf4/package.nix).
  netcdfSupport = netcdfSupport;
  fortranSupport = fortranSupport;
  szipSupport = false;
}).overrideAttrs
  (old: rec {
    pname = mkPackageName old.pname static stdenv;
    buildInputs = [
      zlib
      libjpeg
    ];
    propagatedBuildInputs = buildInputs;
    doCheck = false;

    # nixpkgs' hdf4 sets BUILD_SHARED_LIBS in its own cmakeFlags; replace it
    # instead of adding a conflicting duplicate.
    cmakeFlags =
      let
        oldFlags = old.cmakeFlags or [ ];
        filteredOldFlags = builtins.filter (f: !(lib.hasPrefix "-DBUILD_SHARED_LIBS" f)) oldFlags;
      in
      filteredOldFlags ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];

    meta = old.meta // {
      platforms = lib.platforms.all;
    };
  })
