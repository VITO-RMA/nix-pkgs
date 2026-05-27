{
  lib,
  stdenv,
  netcdffortran,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  netcdf,
  hdf5,
}:

(netcdffortran.override {
  inherit netcdf hdf5;
  # curl is only needed for DAP support, which is disabled in our netcdf
  curl = null;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    configureFlags = (old.configureFlags or [ ]) ++ lib.optionals static [
      "--disable-shared"
      "--enable-static"
    ];

    meta = old.meta // {
      platforms = lib.platforms.all;
    };
  })
