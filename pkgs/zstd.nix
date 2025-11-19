# the upstream zstd seems overly complex for our use case and does not install the static library
{
  lib,
  stdenv,
  fetchFromGitHub,
  fixDarwinDylibNames,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
}:

stdenv.mkDerivation rec {
  pname = "zstd";
  version = "1.5.7";

  src = fetchFromGitHub {
    owner = "facebook";
    repo = "zstd";
    rev = "v${version}";
    hash = "sha256-tNFWIT9ydfozB8dWcmTMuZLCQmQudTFJIkSr0aG7S44=";
  };

  # no longer needed in the next release
  sourceRoot = "source/build/cmake";

  nativeBuildInputs = [ cmake ] ++ lib.optional stdenv.hostPlatform.isDarwin fixDarwinDylibNames;

  enableParallelBuilding = true;
  doInstallCheck = true;

  cmakeFlags = [
    "-DZSTD_LEGACY_SUPPORT=1"
    "-DZSTD_BUILD_TESTS=0"
    "-DZSTD_BUILD_CONTRIB=0"
    "-DZSTD_MULTITHREAD_SUPPORT=1"
    "-DZSTD_BUILD_PROGRAMS=OFF"
  ]
  ++ [
    (lib.cmakeBool "ZSTD_BUILD_SHARED" (!static))
    (lib.cmakeBool "ZSTD_BUILD_STATIC" (static))
  ];

  meta = with lib; {
    description = "Zstandard real-time compression algorithm";
    longDescription = ''
      Zstd, short for Zstandard, is a fast lossless compression algorithm,
      targeting real-time compression scenarios at zlib-level compression
      ratio. Zstd can also offer stronger compression ratio at the cost of
      compression speed. Speed/ratio trade-off is configurable by small
      increment, to fit different situations. Note however that decompression
      speed is preserved and remain roughly the same at all settings, a
      property shared by most LZ compression algorithms, such as zlib.
    '';
    homepage = "https://facebook.github.io/zstd/";
    changelog = "https://github.com/facebook/zstd/blob/v${version}/CHANGELOG";
    license = with licenses; [ bsd3 ]; # Or, at your opinion, GPL-2.0-only.
    pkgConfigModules = [
      "libzstd"
    ];
    platforms = platforms.all;
  };
}
