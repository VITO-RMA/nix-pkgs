{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  python3,
  boost,
  qtbase,
  xerces-c,
  gdal,
  ncurses,
  gnumake,
  static ? stdenv.hostPlatform.isStatic,
  withPython ? !stdenv.hostPlatform.isWindows,
  mkPackageName,
}:

let
  rasterformat-src = fetchFromGitHub {
    owner = "pcraster";
    repo = "rasterformat";
    rev = "d461046182095d4587092bc8028e3508ff5cef36";
    hash = "sha256-yXdw76e65eUq51YRHEG76lL5V1f6NudA3YdHdi7YhRw=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = mkPackageName "pcraster" static stdenv;
  version = "4.5.0-unstable-2026-06-26";

  src = fetchFromGitHub {
    owner = "pcraster";
    repo = "pcraster";
    rev = "0aaf8d143ab8d97da2ec62fe59bf56370d0a6df0";
    hash = "sha256-DTOTVzJoovEj2IN91McUu8Rcf+w6qU0sQ+1ZUwDYeZs=";
  };

  # Remove aggressive linker flags that are incompatible with Nix's
  # library dependency model (--no-undefined, --as-needed, -z defs,
  # --no-copy-dt-needed-entries cause issues with indirect shared lib deps).
  postPatch = ''
    sed -i \
      -e 's/-Wl,--no-undefined;//g' \
      -e 's/-Wl,--as-needed;//g' \
      -e 's/-Wl,-z,defs;//g' \
      -e 's/;-Wl,--no-copy-dt-needed-entries//g' \
      environment/cmake/PCRasterCompilerConfiguration.cmake
  ''
  + lib.optionalString (!withPython) ''
    # When building without Python bindings, downgrade Python to
    # Interpreter-only (still needed for build-time code generation)
    # and skip pybind11 entirely.
    sed -i \
      -e 's/REQUIRED COMPONENTS Interpreter Development NumPy/REQUIRED COMPONENTS Interpreter/' \
      -e '/OPTIONAL_COMPONENTS Development.SABIModule/d' \
      -e '/find_package(pybind11/d' \
      environment/cmake/PCRasterConfiguration.cmake
    sed -i \
      -e '/add_subdirectory(pcraster_python)/d' \
      -e '/add_subdirectory(python_modelling_framework)/d' \
      -e '/add_subdirectory(python_arrayed_variables)/d' \
      source/CMakeLists.txt
    sed -i \
      -e '/add_subdirectory(python)/d' \
      source/modflow/CMakeLists.txt
  ''
  + lib.optionalString (stdenv.hostPlatform != stdenv.buildPlatform) ''
    # When cross-compiling, gdal_translate can't run on the build machine.
    # It's only used as a fallback to locate GDAL_DATA and for tests (disabled).
    sed -i 's/find_program(GDAL_TRANSLATE gdal_translate REQUIRED)/find_program(GDAL_TRANSLATE gdal_translate)/' \
      environment/cmake/PCRasterConfiguration.cmake
    # Fix 64-bit pointer cast in DynamicLibrary (HINSTANCE is 64-bit on x86_64)
    sed -i 's/(unsigned)(d_dllHandle)/(uintptr_t)(d_dllHandle)/' \
      source/pcrcom/com_dynamiclibrary.cc
    # MSVC's __try/__except SEH is not supported by GCC/MinGW in C++.
    # Use _MSC_VER guard instead of WIN32 so MinGW takes the no-SEH path.
    sed -i 's/#ifndef WIN32/#ifndef _MSC_VER/' \
      source/pcraster_model_engine/calc_linkinlibrary.cc
  ''
  + lib.optionalString static ''
    # Remove hardcoded SHARED from internal libraries so they respect
    # BUILD_SHARED_LIBS and get built as static archives.
    sed -i 's/add_library(pcraster_dal SHARED/add_library(pcraster_dal/' \
      source/pcraster_dal/CMakeLists.txt
    sed -i 's/add_library(pcraster_model_engine SHARED/add_library(pcraster_model_engine/' \
      source/pcraster_model_engine/CMakeLists.txt
    # Remove dllimport decoration when linking statically
    sed -i '/PCR_DAL_SHARED_LINK/d' \
      source/pcraster_model_engine/CMakeLists.txt \
      source/pcraster_dal/CMakeLists.txt
    # When PCR_DAL_SHARED_LINK is unset, dal_Configure.h defaults PCR_DAL_DECL
    # to the literal token "error". Make it empty for static builds.
    sed -i 's/#  define PCR_DAL_DECL error/#  define PCR_DAL_DECL/' \
      source/pcraster_dal/dal_Configure.h
    # Use our XercesCConfig.cmake which propagates ICU for static builds
    sed -i 's/find_package(XercesC REQUIRED)/find_package(XercesC CONFIG REQUIRED)/' \
      environment/cmake/PCRasterConfiguration.cmake
  '';

  dontWrapQtApps = true;

  nativeBuildInputs = [
    cmake
    gnumake
    python3
  ];

  buildInputs = [
    boost
    gdal
    ncurses
    qtbase
    xerces-c
  ]
  ++ lib.optionals withPython [
    python3
    python3.pkgs.numpy
    python3.pkgs.pybind11
  ];

  propagatedBuildInputs = finalAttrs.buildInputs;

  # MinGW doesn't predefine WIN32 (only _WIN32); pcraster's source uses
  # #ifdef WIN32 throughout for Windows-specific code paths.
  # Also map MSVC-specific _chdir/_getcwd to POSIX equivalents available in MinGW.
  env = lib.optionalAttrs stdenv.hostPlatform.isMinGW {
    NIX_CFLAGS_COMPILE = "-DWIN32 -D_chdir=chdir -D_getcwd=getcwd -D_getpid=getpid -Wno-error=incompatible-pointer-types";
  };

  cmakeFlags = [
    "-DCPM_rasterformat_SOURCE=${rasterformat-src}"

    # Disable optional components (matches vcpkg port)
    "-DPCRASTER_BUILD_DOCUMENTATION=OFF"
    "-DPCRASTER_BUILD_TEST=OFF"
    "-DPCRASTER_BUILD_AGUILA=OFF"
    "-DPCRASTER_BUILD_MODFLOW=${if withPython then "ON" else "OFF"}"
    "-DPCRASTER_BUILD_MULTICORE=OFF"
    "-DPCRASTER_BUILD_BLOCKPYTHON=OFF"
    "-DPCRASTER_BUILD_MLDD=OFF"
    "-DPCRASTER_BUILD_MOC=OFF"
    "-DPCRASTER_BUILD_OLDCALC=OFF"

    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ];

  enableParallelBuilding = true;

  meta = with lib; {
    description = "Environmental modelling software";
    homepage = "https://pcraster.geo.uu.nl/";
    license = licenses.gpl3;
    platforms = platforms.all;
    maintainers = [ ];
  };
})
