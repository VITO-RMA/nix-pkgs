{
  lib,
  stdenv,
  netcdffortran,
  cmake,
  m4,
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

    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [
      cmake
      m4
    ];
    patches = (old.patches or [ ]) ++ [ ./patches/netcdf-fortran-cmake.patch ];
    propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ netcdf ];

    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
      # Nested upstream CMakeLists still request pre-3.5 policy compatibility.
      "-DCMAKE_POLICY_VERSION_MINIMUM=3.5"
      "-DENABLE_TESTS=OFF"
      "-DBUILD_EXAMPLES=OFF"
    ];

    meta = old.meta // {
      platforms = lib.platforms.all;
    };
  })
