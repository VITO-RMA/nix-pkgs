{
  lib,
  stdenv,
  fetchgit,
  cmake,
  ninja,
  python3,
  rustPlatform,
  darwinMinVersionHook,
  static ? stdenv.hostPlatform.isStatic,
  withWgpu ? false,
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
  wgpuNative = rustPlatform.buildRustPackage {
    inherit stdenv;
    pname = mkPackageName "maplibre-wgpu-native" static stdenv;
    inherit version;
    src = "${src}/vendor/wgpu-native";
    cargoHash = "sha256-MJC9tQvF1DOAB3ggRPoHJdkcCPfW4z8F6YmCQg9OKBs=";
    nativeBuildInputs = [ rustPlatform.bindgenHook ];
    # Only the static archive is needed, including on musl targets where Rust
    # does not support building a cdylib.
    postPatch = ''
      substituteInPlace Cargo.toml \
        --replace-fail 'crate-type = ["cdylib", "staticlib"]' 'crate-type = ["staticlib"]'
    '';
    doCheck = false;
    installPhase = ''
      runHook preInstall
      mkdir -p $out/lib
      cp target/${stdenv.hostPlatform.rust.rustcTarget}/release/libwgpu_native.a $out/lib/
      runHook postInstall
    '';
  };
in
stdenv.mkDerivation {
  pname = mkPackageName (
    if withWgpu then "maplibre-native-wgpu" else "maplibre-native"
  ) static stdenv;
  inherit version src;

  nativeBuildInputs = [
    cmake
    ninja
  ]
  ++ lib.optional withWgpu python3
  ++ lib.optional stdenv.hostPlatform.isDarwin (darwinMinVersionHook "14.3");

  # Upstream always builds mbgl-core as a static archive. The core-only API
  # deliberately leaves platform services to the embedding application.
  cmakeFlags = [
    "-DMLN_WITH_CORE_ONLY=ON"
    (lib.cmakeBool "MLN_WITH_WEBGPU" withWgpu)
    "-DMLN_USE_RUST=OFF"
    "-DMLN_WITH_OPENGL=OFF"
    (lib.cmakeBool "MLN_WITH_VULKAN" (!withWgpu && stdenv.hostPlatform.isLinux))
    (lib.cmakeBool "MLN_WITH_METAL" (!withWgpu && stdenv.hostPlatform.isDarwin))
    "-DMLN_WITH_QT=OFF"
    "-DMLN_WITH_GLFW=OFF"
    "-DMLN_WITH_RTTI=ON"
    "-DMLN_WITH_WERROR=OFF"
    "-DBUILD_TESTING=OFF"
  ]
  ++ lib.optionals withWgpu [
    "-DMLN_WEBGPU_IMPL_WGPU=ON"
    "-DWGPU_LIBRARY=${wgpuNative}/lib/libwgpu_native.a"
    "-DWGPU_STATIC_LIBRARY=${wgpuNative}/lib/libwgpu_native.a"
  ];

  postPatch = lib.optionalString withWgpu ''
    # Keep the generated, installed shim independent of the build directory.
    substituteInPlace vendor/wgpu.cmake \
      --replace-fail '#include \"''${_webgpu_cpp_header}\"' '#include <webgpu.hpp>'
  '';

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
    description = "MapLibre Native C++ core with ${
      if withWgpu then "wgpu WebGPU support" else "Vulkan on Linux and Metal on macOS"
    }";
    license = lib.licenses.bsd2;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
