# upstream package splits the header and library files into multiple sub-packages causing issues
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  mkPackageName,
  cppSupport ? true,
  fortranSupport ? false,
  fortran,
  zlibSupport ? true,
  zlib,
  szipSupport ? false,
  szip,
  mpiSupport ? false,
  mpi,
  static ? stdenv.hostPlatform.isStatic,
  threadsafe ? false,
}:

# cpp and mpi options are mutually exclusive
# "-DALLOW_UNSUPPORTED=ON" could be used to force the build.
assert !cppSupport || !mpiSupport;

let
  inherit (lib) optional;
in

stdenv.mkDerivation rec {
  version = "1.14.6";
  pname = mkPackageName "hdf5" static stdenv;

  src = fetchFromGitHub {
    owner = "HDFGroup";
    repo = "hdf5";
    rev = "hdf5_${version}";
    hash = "sha256-mJTax+VWAL3Amkq3Ij8fxazY2nfpMOTxYMUQlTvY/rg=";
  };

  patches = [ ./patches/hdf5-config.patch ];

  passthru = {
    inherit
      cppSupport
      fortranSupport
      fortran
      zlibSupport
      zlib
      szipSupport
      szip
      mpiSupport
      mpi
      ;
  };

  nativeBuildInputs = [
    cmake
  ]
  ++ optional fortranSupport fortran;

  buildInputs = optional fortranSupport fortran ++ optional szipSupport szip;

  propagatedBuildInputs = optional zlibSupport zlib ++ optional mpiSupport mpi;

  cmakeFlags = [
    "-DHDF5_BUILD_HL_LIB=ON"
    "-DHDF5_BUILD_TOOLS=OFF"
    "-DBUILD_TESTING=OFF"
    "-DHDF5_ALLOW_EXTERNAL_SUPPORT=NO"
    "-DHDF5_BUILD_EXAMPLES=OFF"
    "-DHDF_PACKAGE_NAMESPACE:STRING=hdf5::"
    # -DHDF5_MSVC_NAMING_CONVENTION=OFF
    (lib.cmakeBool "BUILD_STATIC_LIBS" static)
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    (lib.cmakeBool "HDF5_BUILD_CPP_LIB" cppSupport)
    (lib.cmakeBool "HDF5_BUILD_FORTRAN" fortranSupport)
    (lib.cmakeBool "HDF5_ENABLE_PARALLEL" mpiSupport)
    (lib.cmakeBool "HDF5_ENABLE_THREADSAFE" threadsafe)
    (lib.cmakeBool "HDF5_ENABLE_Z_LIB_SUPPORT" zlibSupport)
    (lib.cmakeBool "HDF5_ENABLE_SZIP_SUPPORT" szipSupport)
    (lib.cmakeBool "HDF5_ENABLE_SZIP_ENCODING" szipSupport)
  ]
  ++ lib.optional stdenv.hostPlatform.isDarwin "-DHDF5_BUILD_WITH_INSTALL_NAME=ON"
  # broken in nixpkgs since around 1.14.3 -> 1.14.4.3
  # https://github.com/HDFGroup/hdf5/issues/4208#issuecomment-2098698567
  ++ lib.optional stdenv.hostPlatform.isMusl "-DHDF5_ENABLE_NONSTANDARD_FEATURE_FLOAT16=OFF"
  ++ lib.optional (
    stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isx86_64
  ) "-DHDF5_ENABLE_NONSTANDARD_FEATURE_FLOAT16=OFF";

  enableParallelBuilding = true;

  meta = with lib; {
    description = "Data model, library, and file format for storing and managing data";
    longDescription = ''
      HDF5 supports an unlimited variety of datatypes, and is designed for flexible and efficient
      I/O and for high volume and complex data. HDF5 is portable and is extensible, allowing
      applications to evolve in their use of HDF5. The HDF5 Technology suite includes tools and
      applications for managing, manipulating, viewing, and analyzing data in the HDF5 format.
    '';
    license = licenses.bsd3; # Lawrence Berkeley National Labs BSD 3-Clause variant
    homepage = "https://www.hdfgroup.org/HDF5/";
    platforms = platforms.all;
  };
}
