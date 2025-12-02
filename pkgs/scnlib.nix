{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  fast-float,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "scnlib" static stdenv;
  version = "v4.0.1";

  src = fetchFromGitHub {
    owner = "eliaskosunen";
    repo = "scnlib";
    rev = version;
    sha256 = "sha256-qEZAWhtvhKMkh7fk1yD17ErWGCpztEs0seV4AkBOy1I=";
  };

  patches = [
    ./patches/scnlib-fast-float.patch
  ];

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    fast-float
  ];

  transitiveBuildInputs = buildInputs;

  cmakeFlags = [
    "-DSCN_TESTS=OFF"
    "-DSCN_EXAMPLES=OFF"
    "-DSCN_BENCHMARKS=OFF"
    "-DSCN_DOCS=OFF"
    "-DSCN_USE_EXTERNAL_FAST_FLOAT=ON"
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ];

  meta = with lib; {
    homepage = "https://github.com/eliaskosunen/scnlib";
    description = "scanf for modern C++";
    platforms = platforms.all;
    license = licenses.apsl20;
  };
}
