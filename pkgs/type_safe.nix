{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "type_safe" static stdenv;
  version = "v0.2.4";

  src = fetchFromGitHub {
    owner = "foonathan";
    repo = "type_safe";
    rev = version;
    sha256 = "sha256-z8muv/fl7+7NEZly/CHlBqjy4mIjnWRPSxxVIXp6ZGE=";
  };

  patches = [
    ./patches/type_safe-min-cmake-version.patch
  ];

  nativeBuildInputs = [
    cmake
  ];

  cmakeFlags = [
    "-DTYPE_SAFE_BUILD_TEST_EXAMPLE=OFF"
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
