{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  python3,
  boost,
  qt6,
  xerces-c,
  gdal,
  ncurses,
  gnumake,
  static ? stdenv.hostPlatform.isStatic,
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
  '';

  mingwSupport = false;
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
    python3
    python3.pkgs.numpy
    python3.pkgs.pybind11
    qt6.qtbase
    xerces-c
  ];

  propagatedBuildInputs = finalAttrs.buildInputs;

  cmakeFlags = [
    "-DCPM_rasterformat_SOURCE=${rasterformat-src}"

    # Disable optional components (matches vcpkg port)
    "-DPCRASTER_BUILD_DOCUMENTATION=OFF"
    "-DPCRASTER_BUILD_TEST=OFF"
    "-DPCRASTER_BUILD_AGUILA=OFF"
    "-DPCRASTER_BUILD_MODFLOW=ON"
    "-DPCRASTER_BUILD_MULTICORE=OFF"
    "-DPCRASTER_BUILD_BLOCKPYTHON=OFF"
    "-DPCRASTER_BUILD_MLDD=OFF"
    "-DPCRASTER_BUILD_MOC=OFF"

    # Allow indirect shared library dependencies (e.g., xerces-c → curl)
    # to have unresolved symbols at link time; they resolve at runtime.
    "-DCMAKE_EXE_LINKER_FLAGS=-Wl,--allow-shlib-undefined"
    "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--allow-shlib-undefined"
  ];

  enableParallelBuilding = true;

  meta = with lib; {
    description = "Environmental modelling software";
    homepage = "https://pcraster.geo.uu.nl/";
    license = licenses.gpl3;
    platforms = platforms.unix;
    maintainers = [ ];
  };
})
