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
  isMsvc =
    (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));
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

  # This toolchain is clang driven by its GNU driver (not clang-cl). CMake
  # therefore (by design) leaves `MSVC` unset — it only sets `MSVC` for the
  # clang-cl frontend, since `MSVC` means "cl.exe-compatible command line",
  # not "targets the MSVC ABI". HDF5 conflates the two: `ConfigureChecks.cmake`
  # seeds `CMAKE_REQUIRED_FLAGS` with MSVC `/D...` syntax, which the GNU driver
  # treats as input file paths (`no such file or directory: '/DNOGDI=1'`),
  # breaking *every* configure-time `try_compile` (so e.g. `sys/types.h` is
  # reported missing and `off_t` ends up undefined). Rewrite to the `-D` form,
  # which the GNU driver (and cl.exe) both accept.
  postPatch = lib.optionalString isMsvc ''
    substituteInPlace config/cmake/ConfigureChecks.cmake \
      --replace-fail \
        'set (CMAKE_REQUIRED_FLAGS "/DWIN32_LEAN_AND_MEAN=1 /DNOGDI=1")' \
        'set (CMAKE_REQUIRED_FLAGS "-DWIN32_LEAN_AND_MEAN=1 -DNOGDI=1")'
    # HDF5 adds the MSVC `/EHsc` exception flag for any clang simulating MSVC
    # (`_CLANG_MSVC_WINDOWS`), assuming clang-cl. The GNU driver rejects `/EHsc`
    # (`no such file or directory: '/EHsc'`); C++ exceptions are enabled by
    # default for the MSVC ABI anyway, so just drop it.
    substituteInPlace config/cmake/HDFCXXCompilerFlags.cmake \
      --replace-fail \
        'set (CMAKE_CXX_FLAGS "''${CMAKE_CXX_FLAGS} /EHsc")' \
        'set (CMAKE_CXX_FLAGS "''${CMAKE_CXX_FLAGS}")'
  '';

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
  ) "-DHDF5_ENABLE_NONSTANDARD_FEATURE_FLOAT16=OFF"
  # The `HDF5_ENABLE_ALL_WARNINGS` path (default ON) appends MSVC `/Wall`,
  # `/W3`, `/wd####` warning flags under `if(MSVC)`; the GNU-driver clang
  # rejects these `/`-prefixed args. Disable it for the MSVC target.
  ++ lib.optional isMsvc "-DHDF5_ENABLE_ALL_WARNINGS=OFF"
  # `H5_HAVE_VISUAL_STUDIO` guards HDF5's Windows compatibility code
  # (`struct timezone`, the `_get_timezone` path in `H5_make_time`, ...).
  # HDF5 only sets it `if(MSVC)`, but for the GNU-driver clang that is never
  # true, so the Win32 code is left half-defined and fails to compile. It is
  # emitted via `#cmakedefine`, so set the variable directly: this target does
  # use the MSVC ABI / runtime, so the Visual-Studio code paths are correct.
  ++ lib.optional isMsvc "-DH5_HAVE_VISUAL_STUDIO=1";

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
