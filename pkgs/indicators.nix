# not available in nixpkgs
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "indicators" static stdenv;
  version = "v2.3";

  src = fetchFromGitHub {
    owner = "p-ranav";
    repo = "indicators";
    rev = version;
    sha256 = "sha256-FA07UbuhsA7HThbyxHxS+V4H5ha0LAXU7sukVfPVpdg=";
  };

  nativeBuildInputs = [
    cmake
  ];

  cmakeFlags = [
    "-DINDICATORS_BUILD_TESTS=OFF"
    "-DINDICATORS_SAMPLES=OFF"
    "-DINDICATORS_DEMO=OFF"
  ]
  ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];

  meta = with lib; {
    homepage = "https://github.com/p-ranav/indicators";
    description = "Activity Indicators for Modern C++ ";
    platforms = platforms.unix;
    license = licenses.mit;
    maintainers = [ ];
  };
}
