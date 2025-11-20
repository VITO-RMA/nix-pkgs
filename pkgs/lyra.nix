# the upstream lyra package uses the meson build system, which does not install a cmake find config file.
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "lyra" static stdenv;
  version = "1.7.0";

  src = fetchFromGitHub {
    owner = "bfgroup";
    repo = "lyra";
    rev = version;
    sha256 = "sha256-X8wJwSfOo7v2SKYrKJ4RhpEmOdEkS8lPHIqCxP46VF4=";
  };

  nativeBuildInputs = [
    cmake
  ];

  cmakeFlags = [
  ]
  ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];

  meta = with lib; {
    homepage = "https://github.com/bfgroup/Lyra";
    description = "Simple to use, composable, command line parser for C++ 11 and beyond";
    platforms = platforms.unix;
    license = licenses.boost;
    maintainers = [ ];
  };
}
