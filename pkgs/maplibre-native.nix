{
  lib,
  stdenv,
  fetchgit,
  cmake,
  ninja,
  darwinMinVersionHook,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

let
  version = "13.7.1";
  src = fetchgit {
    url = "https://github.com/maplibre/maplibre-native.git";
    # android-v13.7.1, the latest upstream release of the shared C++ core.
    rev = "4cf121e515d8d065b57cd555a0b231ea27ff0e5d";
    hash = "sha256-WqublcOZ+kYqyUer2ktwSmfjISciZZCISJqAGd/wIp8=";
    fetchSubmodules = true;
  };
in
stdenv.mkDerivation {
  pname = mkPackageName "maplibre-native" static stdenv;
  inherit version src;

  nativeBuildInputs = [
    cmake
    ninja
  ]
  ++ lib.optional stdenv.hostPlatform.isDarwin (darwinMinVersionHook "14.3");

  # Upstream always builds mbgl-core as a static archive. The core-only API
  # deliberately leaves platform services to the embedding application.
  cmakeFlags = [
    "-DMLN_WITH_CORE_ONLY=ON"
    "-DMLN_WITH_WEBGPU=OFF"
    "-DMLN_USE_RUST=OFF"
    "-DMLN_WITH_OPENGL=OFF"
    (lib.cmakeBool "MLN_WITH_VULKAN" stdenv.hostPlatform.isLinux)
    (lib.cmakeBool "MLN_WITH_METAL" stdenv.hostPlatform.isDarwin)
    "-DMLN_WITH_QT=OFF"
    "-DMLN_WITH_GLFW=OFF"
    "-DMLN_WITH_RTTI=ON"
    "-DMLN_WITH_WERROR=OFF"
    "-DBUILD_TESTING=OFF"
  ];

  # Core-only upstream has no install rules. A packaging-only parent project
  # installs its targets and headers without changing the upstream sources.
  preConfigure = ''
    mkdir nix-cmake
    cp ${./maplibre-native/CMakeLists.txt} nix-cmake/CMakeLists.txt
    cmakeDir=../nix-cmake
  '';

  passthru = {
    mingwSupport = false;
  };

  meta = {
    homepage = "https://maplibre.org/maplibre-native/";
    description = "MapLibre Native C++ core with Vulkan on Linux and Metal on macOS";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
