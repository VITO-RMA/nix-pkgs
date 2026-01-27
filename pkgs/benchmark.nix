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
  pname = mkPackageName "benchmark" static stdenv;
  version = "v1.9.5";

  src = fetchFromGitHub {
    owner = "google";
    repo = "benchmark";
    rev = version;
    sha256 = "sha256-Mm4pG7zMB00iof32CxreoNBFnduPZTMp3reHMCIAFPQ=";
  };

  nativeBuildInputs = [
    cmake
  ];

  cmakeFlags = [
    "-DBENCHMARK_ENABLE_TESTING=OFF"
    "-DBENCHMARK_INSTALL_DOCS=OFF"
    "-DBENCHMARK_ENABLE_WERROR=OFF"
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ];

  meta = with lib; {
    homepage = "https://github.com/google/benchmark";
    description = "A microbenchmark support library";
    platforms = platforms.all;
    license = licenses.apsl20;
  };
}
