{
  lib,
  stdenv,
  fetchgit,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  sqlite,
  zlib,
  qtbase,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "maplibre-native" static stdenv;
  version = "10.1.0";

  mingwSupport = false;
  dontWrapQtApps = true;

  src = fetchgit {
    url = "https://github.com/maplibre/maplibre-native.git";
    rev = "android-v10.1.0";
    hash = "sha256-dSzHYJ/1GpY1S/kruu8rw4qP+xO17xlZPEv52sHnCuA=";
    fetchSubmodules = true;
  };

  patches = [
    ./patches/maplibre-native-cmake-config.patch
    ./patches/maplibre-native-cmake.patch
    ./patches/maplibre-native-boost-numeric.patch
    ./patches/maplibre-native-timer-overflow.patch
    ./patches/maplibre-native-http2.patch
    ./patches/maplibre-native-fix-includes.patch
  ];

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    sqlite
    zlib
    qtbase
  ];

  transitiveBuildInputs = buildInputs;

  cmakeFlags = [
    "-DMLN_WITH_RTTI=ON"
    "-DMLN_WITH_COVERAGE=OFF"
    "-DMLN_WITH_WERROR=OFF"
    "-DMLN_WITH_QT=ON"
    "-DMLN_QT_LIBRARY_ONLY=ON"
    "-DMLN_QT_STATIC=ON"
    "-DMLN_QT_WITH_INTERNAL_SQLITE=ON"
    "-DMLN_QT_WITH_INTERNAL_ICU=ON"
    #(lib.cmakeBool "MLN_QT_STATIC" (!static))
  ]
  ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];

  meta = with lib; {
    homepage = "https://github.com/foonathan/type_safe";
    description = "Zero overhead utilities for preventing bugs at compile time";
    platforms = platforms.all;
    license = licenses.mit;
    maintainers = [ ];
  };
}
