# keep local until onetbb hits stable
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  hwloc,
  ninja,
  pkg-config,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = mkPackageName "onetbb" static stdenv;
  version = "2023.0.0";

  outputs = [
    "out"
    "dev"
  ];

  src = fetchFromGitHub {
    owner = "oneapi-src";
    repo = "oneTBB";
    tag = "v${finalAttrs.version}";
    hash = "sha256-algLvvVHHCQTiwxNX7gM6vfpSadR7fu49CBtfx2LSPk=";
  };

  patches = [
    # <https://github.com/uxlfoundation/oneTBB/pull/899>
    ./patches/onetbb-fix-musl-build.patch

    # <https://github.com/uxlfoundation/oneTBB/pull/1849>
    ./patches/onetbb-fix-libtbbmalloc-dlopen.patch
  ];

  nativeBuildInputs = [
    cmake
    ninja
    pkg-config
  ];

  buildInputs = [
    hwloc
  ];

  doCheck = false;

  cmakeFlags = [
    "-DTBB_TEST=OFF"
    "-DTBB_STRICT=OFF"
    (lib.cmakeBool "TBB_DISABLE_HWLOC_AUTOMATIC_SEARCH" false)
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ];

  env = {
    # Fix build with modern gcc
    # In member function 'void std::__atomic_base<_IntTp>::store(__int_type, std::memory_order) [with _ITp = bool]',
    NIX_CFLAGS_COMPILE = lib.optionalString stdenv.cc.isGNU "-Wno-error=stringop-overflow";
  };

  meta = {
    description = "oneAPI Threading Building Blocks";
    homepage = "https://uxlfoundation.github.io/oneTBB/";
    license = lib.licenses.asl20;
    longDescription = ''
      oneAPI Threading Building Blocks (oneTBB) is a runtime-based
      parallel programming model for C++ code that uses tasks. The
      template-based runtime library can help you harness the latent
      performance of multi-core processors.
    '';
    platforms = lib.platforms.all;
  };
})
