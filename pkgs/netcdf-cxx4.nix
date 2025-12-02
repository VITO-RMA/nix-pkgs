{
  lib,
  stdenv,
  netcdfcxx4,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  netcdf,
  hdf5,
}:

(netcdfcxx4.override {
  inherit netcdf hdf5;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    patches = [
      ./patches/netcdf-cxx4-hdf5-dep.patch
    ];

    postPatch = ''
      substituteInPlace CMakeLists.txt \
        --replace "cmake_minimum_required(VERSION 2.8.12)" "cmake_minimum_required(VERSION 3.21)"
    '';

    buildInputs = [
      netcdf
      hdf5
    ];

    cmakeFlags = old.cmakeFlags or [ ] ++ [
      "-DNCXX_ENABLE_TESTS=OFF"
      (lib.cmakeBool "NC_HAS_DEF_VAR_FILTER" (!static)) # do not build the plugins in static builds
      (lib.cmakeBool "HDF5_USE_STATIC_LIBRARIES" static)
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    ];

    meta.platforms = lib.platforms.all;
  })
