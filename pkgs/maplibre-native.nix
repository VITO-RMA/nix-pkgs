{
  lib,
  stdenv,
  fetchgit,
  cmake,
  ninja,
  python3,
  swift,
  pkg-config,
  curl,
  libjpeg,
  libpng,
  libwebp,
  libuv,
  icu,
  zlib,
  libglvnd,
  rustPlatform,
  darwinMinVersionHook,
  static ? stdenv.hostPlatform.isStatic,
  withWgpu ? false,
  coreOnly ? !withWgpu,
  withWgpuFfi ? false,
  webgpuHeader ? null,
  mkPackageName,
}:

let
  version = "13.6.0";
  src = fetchgit {
    url = "https://github.com/maplibre/maplibre-native.git";
    # android-v13.6.0 release of the shared C++ core.
    rev = "2919f71e394876ecca220a7a620000e337b318f2";
    hash = "sha256-84wCG5BP3ijS3Q46d+zJ6mi5VuFWoAgQDir3wEfJP68=";
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
  ++ lib.optional (!coreOnly) pkg-config
  ++ lib.optional (!coreOnly && stdenv.hostPlatform.isDarwin) swift
  ++ lib.optional stdenv.hostPlatform.isDarwin (darwinMinVersionHook "14.3");

  buildInputs =
    lib.optionals (!coreOnly) [
      curl
      libjpeg
      libpng
      libwebp
      libuv
      icu
      zlib
    ]
    ++ lib.optional (!coreOnly && stdenv.hostPlatform.isLinux && withWgpu) libglvnd;

  # The Rust bindings require the default platform implementation (RunLoop,
  # HeadlessFrontend, file sources, Unicode and SQLite), not just the core.
  cmakeFlags = [
    (lib.cmakeBool "MLN_WITH_CORE_ONLY" coreOnly)
    (lib.cmakeBool "MLN_WITH_WEBGPU" withWgpu)
    "-DMLN_USE_RUST=OFF"
    "-DMLN_WITH_OPENGL=OFF"
    (lib.cmakeBool "MLN_WITH_VULKAN" (!withWgpu && stdenv.hostPlatform.isLinux))
    (lib.cmakeBool "MLN_WITH_METAL" (!withWgpu && stdenv.hostPlatform.isDarwin))
    "-DMLN_WITH_QT=OFF"
    "-DMLN_WITH_GLFW=OFF"
    "-DMLN_WITH_X11=OFF"
    "-DMLN_WITH_WAYLAND=OFF"
    (lib.cmakeBool "MLN_WITH_EGL" (!coreOnly && withWgpu && stdenv.hostPlatform.isLinux))
    "-DMLN_WITH_RTTI=ON"
    "-DMLN_WITH_WERROR=OFF"
    "-DBUILD_TESTING=OFF"
  ]
  ++ lib.optionals withWgpu [
    "-DMLN_WEBGPU_IMPL_WGPU=ON"
    (lib.cmakeBool "MLN_WEBGPU_IMPL_FFI" withWgpuFfi)
  ]
  ++ lib.optionals (withWgpu && !withWgpuFfi) [
    "-DWGPU_LIBRARY=${wgpuNative}/lib/libwgpu_native.a"
    "-DWGPU_STATIC_LIBRARY=${wgpuNative}/lib/libwgpu_native.a"
  ];

  ninjaFlags = [ "mbgl-core" ];

  postPatch =
    lib.optionalString withWgpu ''
      # Keep the generated, installed shim independent of the build directory.
      substituteInPlace vendor/wgpu.cmake \
        --replace-fail '#include \"''${_webgpu_cpp_header}\"' '#include <webgpu.hpp>'
    ''
    + lib.optionalString withWgpuFfi ''
      # FFI consumers implement the standard WebGPU API, not wgpu-native's
      # extension API. The latter also conflicts with newer webgpu.h files.
      substituteInPlace src/mln/webgpu/headless_backend.cpp \
        --replace-fail '#include <wgpu.h>' '#include <webgpu.h>'
      substituteInPlace src/mln/webgpu/offscreen_texture.cpp \
        --replace-fail '#include <webgpu/wgpu.h>' '#include <webgpu/webgpu.h>' \
        --replace-fail $'#if MLN_WEBGPU_IMPL_DAWN\n' $'#if MLN_WEBGPU_IMPL_DAWN || MLN_WEBGPU_IMPL_FFI\n'
    ''
    + lib.optionalString (withWgpuFfi && webgpuHeader != null) ''
      cp ${webgpuHeader} vendor/wgpu-native/ffi/webgpu-headers/webgpu.h
    '';

  # Core-only upstream has no install rules. A packaging-only parent project
  # installs its targets and headers without changing the upstream sources.
  preConfigure = ''
    mkdir nix-cmake
    cp ${./maplibre-native/CMakeLists.txt} nix-cmake/CMakeLists.txt
    cmakeDir=../nix-cmake
  '';

  # Link against the installed CMake package, not the build-tree targets. This
  # catches missing vendor archives, platform services and exported dependencies.
  doInstallCheck = !coreOnly && !withWgpuFfi;
  installCheckPhase = ''
    runHook preInstallCheck
    mkdir -p install-check
    cat > install-check/CMakeLists.txt <<'EOF'
    cmake_minimum_required(VERSION 3.25)
    project(MapLibreNativeInstallCheck LANGUAGES CXX)
    find_package(MapLibreNative REQUIRED)
    add_executable(platform-link main.cpp)
    target_link_libraries(platform-link PRIVATE MapLibreNative::Core)
    EOF
    cat > install-check/main.cpp <<'EOF'
    #include <mln/gfx/headless_frontend.hpp>
    #include <mln/util/run_loop.hpp>
    void check_frontend() {
        mln::HeadlessFrontend frontend(mln::Size{32, 32}, 1.0f);
    }
    int main() {
        mln::util::RunLoop loop;
    }
    EOF
    cmake -S install-check -B install-check/build -G Ninja \
      -DCMAKE_PREFIX_PATH="$out" -DCMAKE_BUILD_TYPE=Release
    cmake --build install-check/build
    runHook postInstallCheck
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
