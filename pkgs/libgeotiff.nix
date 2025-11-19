# the upstream lyra package uses the meson build system, which does not install a cmake find config file.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  libtiff,
  lerc,
  proj,
  zlib,
  zstd,
  static ? stdenv.hostPlatform.isStatic,
}:

let
  exts = stdenv.hostPlatform.extensions or {};
  ext = if static then (exts.staticLibrary or ".a") else (exts.sharedLibrary or ".so");
in
stdenv.mkDerivation rec {
  pname = "libgeotiff";
  version = "1.7.4";

  src = fetchFromGitHub {
    owner = "OSGeo";
    repo = "libgeotiff";
    rev = version;
    sha256 = "sha256-oiuooLejCRI1DFTjhgYoePtKS+OAGnW6OBzgITcY500=";
  };

  patches = [
    ./patches/libgeotiff-find-tiff.patch
  ];

  sourceRoot = "source/libgeotiff";

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    libtiff
    lerc
    proj
    zlib
    zstd
  ];

  propagatedBuildInputs = buildInputs;

  cmakeFlags = [
    "-DBUILD_MAN=OFF"
    "-DBUILD_DOC=OFF"
    "-DWITH_UTILITIES=OFF"
    "-DWITH_ZLIB=ON"
    "-DWITH_TIFF=ON"
    "-DWITH_JPEG=OFF"
    # Set these hard coded to avoid config errors with static builds
    "-DHAVE_TIFF=1"
    "-DHAVE_TIFFOPEN=1"
    "-DHAVE_TIFFMERGEFIELDINFO=1"
    "-DZLIB_INCLUDE_DIR=${lib.getDev zlib}/include"
    "-DZLIB_LIBRARY=${lib.getLib zlib}/lib/libz${ext}"
    "-Dzstd_DIR=${lib.getLib zstd}/lib/cmake/zstd"
  ]
  ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];

  meta = with lib; {
    description = "Library implementing attempt to create a tiff based interchange format for georeferenced raster imagery";
    homepage = "https://github.com/OSGeo/libgeotiff";
    changelog = "https://github.com/OSGeo/libgeotiff/blob/${src.rev}/libgeotiff/NEWS";
    license = licenses.mit;
    platforms = with platforms; linux ++ darwin;
  };
}
