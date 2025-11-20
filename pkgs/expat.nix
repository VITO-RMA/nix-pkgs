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
  pname = mkPackageName "expat" static stdenv;
  version = "R_2_7_3";

  src = fetchFromGitHub {
    owner = "libexpat";
    repo = "libexpat";
    rev = version;
    sha256 = "sha256-dDxnAJsj515vr9+j2Uqa9E+bB+teIBfsnrexppBtdXg=";
  };

  sourceRoot = "source/expat";

  nativeBuildInputs = [
    cmake
  ];

  cmakeFlags = [
    "-DEXPAT_BUILD_EXAMPLES=OFF"
    "-DEXPAT_BUILD_TESTS=OFF"
    "-DEXPAT_BUILD_TOOLS=OFF"
    "-DEXPAT_BUILD_DOCS=OFF"
    "-DEXPAT_BUILD_PKGCONFIG=ON"
    "-DINDICATORS_BUILD_TESTS=OFF"
    "-DINDICATORS_SAMPLES=OFF"
    "-DINDICATORS_DEMO=OFF"
  ]
  ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];

  meta = with lib; {
    homepage = "https://github.com/libexpat/libexpat";
    description = "XML parser library written in C";
    platforms = platforms.all;
    pkgConfigModules = [
      "expat"
    ];
    license = licenses.mit;
    maintainers = [ ];
  };
}
