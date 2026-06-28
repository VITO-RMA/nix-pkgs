# upstream package uses autotools so there is no cmake module
{
  lib,
  stdenv,
  fetchurl,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "shapelib" static stdenv;
  version = "1.6.3";

  src = fetchurl {
    url = "https://download.osgeo.org/shapelib/shapelib-${version}.tar.gz";
    hash = "sha256-P/Xq0Yym0v4knw6As2HhrWeCFlEVJo7UpYx4CmDB4Os=";
  };

  nativeBuildInputs = [
    cmake
  ];

  cmakeFlags = [
    "-DBUILD_SHAPELIB_CONTRIB=OFF"
    "-DBUILD_APPS=OFF"
    "-DBUILD_TESTING=OFF"
    "-DUSE_RPATH=OFF"
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ];

  meta = with lib; {
    description = "C Library for reading, writing and updating ESRI Shapefiles";
    homepage = "http://shapelib.maptools.org/";
    license = licenses.gpl2;
    changelog = "http://shapelib.maptools.org/release.html";
  };
}
