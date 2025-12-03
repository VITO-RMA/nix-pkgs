{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "debug_assert" static stdenv;
  version = "v1.3.4";

  src = fetchFromGitHub {
    owner = "foonathan";
    repo = "debug_assert";
    rev = version;
    sha256 = "sha256-aZEiaKyK96afL8ZAT/yLYr8NSPXLaFPhNDsPBBN0PH0=";
  };

  prePatch = ''
    substituteInPlace CMakeLists.txt \
      --replace "cmake_minimum_required(VERSION 3.5)" "cmake_minimum_required(VERSION 3.21)"
  '';

  nativeBuildInputs = [
    cmake
  ];

  cmakeFlags = [
    "-DDEBUG_ASSERT_INSTALL=ON"
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ];

  meta = with lib; {
    homepage = "https://github.com/foonathan/debug_assert";
    description = "Simple, flexible and modular assertion macro.";
    platforms = platforms.all;
    license = licenses.zlib;
  };
}
