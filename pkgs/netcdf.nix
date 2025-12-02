{
  lib,
  stdenv,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  fetchFromGitHub,
  cmake,
  zlib,
  hdf5,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "netcdf" static stdenv;
  version = "4.9.3";

  src = fetchFromGitHub {
    owner = "Unidata";
    repo = "netcdf-c";
    rev = "v${version}";
    sha256 = "sha256-MxLMudrVWuiYYAkTjX7O/+ZDae9K5Fpbus1J2PmVzJ8=";
  };

  patches = [
    ./patches/netcdf-dependencies.patch
    ./patches/netcdf-pkgconfig.patch
    ./patches/netcdf-mingw-stat.patch
  ];

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    zlib
    hdf5
  ];

  propagatedBuildInputs = buildInputs;

  cmakeFlags = [
    "-DHDF5_VERSION=1.14.6"
    "-DBUILD_TESTING=OFF"
    "-DNETCDF_ENABLE_DAP_REMOTE_TESTS=OFF"
    "-DNETCDF_ENABLE_EXAMPLES=OFF"
    "-DNETCDF_ENABLE_FILTER_BLOSC=OFF"
    "-DNETCDF_ENABLE_FILTER_TESTING=OFF"
    "-DNETCDF_ENABLE_LIBXML2=OFF"
    "-DNETCDF_ENABLE_S3=OFF"
    "-DNETCDF_ENABLE_TESTS=OFF"
    "-DNETCDF_ENABLE_DAP=OFF"
    "-DNETCDF_ENABLE_NCZARR=OFF"
    "-DNETCDF_ENABLE_NCZARR_ZIP=OFF"
    "-DNETCDF_ENABLE_HDF5=ON"
    "-DNETCDF_ENABLE_PLUGINS=OFF"
    "-DNETCDF_ENABLE_FILTER_BZ2=OFF"
    "-DNETCDF_ENABLE_FILTER_SZIP=OFF"
    "-DNETCDF_BUILD_UTILITIES=OFF"
    "-DNETCDF_ENABLE_FILTER_ZSTD=OFF"
    "-DDISABLE_INSTALL_DEPENDENCIES=ON"
    "-DHDF5_DIR=${hdf5}/cmake"
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ];

  meta = {
    description = "Libraries for the Unidata network Common Data Format";
    platforms = lib.platforms.all;
    homepage = "https://www.unidata.ucar.edu/software/netcdf/";
    changelog = "https://docs.unidata.ucar.edu/netcdf-c/${version}/RELEASE_NOTES.html";
    license = lib.licenses.bsd3;
  };
}
