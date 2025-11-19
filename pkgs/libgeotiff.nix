# the upstream lyra package uses the meson build system, which does not install a cmake find config file.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  libtiff,
  proj,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
}:

stdenv.mkDerivation rec {
  pname = "libgeotiff";
  version = "1.7.4";

  src = fetchFromGitHub {
    owner = "OSGeo";
    repo = "libgeotiff";
    rev = version;
    sha256 = "sha256-oiuooLejCRI1DFTjhgYoePtKS+OAGnW6OBzgITcY500=";
  };

  sourceRoot = "source/libgeotiff";

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    libtiff
    proj
    zlib
  ];

  cmakeFlags = [
    "-DBUILD_MAN=OFF"
    "-DBUILD_DOC=OFF"
    "-DWITH_UTILITIES=OFF"
    "-DWITH_ZLIB=ON"
    "-DWITH_TIFF=ON"
    "-DWITH_JPEG=OFF"
  ]
  ++ (if static then [ "-DBUILD_SHARED_LIBS=OFF" ] else [ "-DBUILD_SHARED_LIBS=ON" ]);

  meta = with lib; {
    description = "Library implementing attempt to create a tiff based interchange format for georeferenced raster imagery";
    homepage = "https://github.com/OSGeo/libgeotiff";
    changelog = "https://github.com/OSGeo/libgeotiff/blob/${src.rev}/libgeotiff/NEWS";
    license = licenses.mit;
    platforms = with platforms; linux ++ darwin;
  };
}
