# version in nixpkgs uses meson and does not compile on mingw
{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "tomlplusplus" static stdenv;
  version = "3.4.0";

  src = fetchFromGitHub {
      owner = "marzer";
      repo = "tomlplusplus";
      tag = "v${version}";
      hash = "sha256-h5tbO0Rv2tZezY58yUbyRVpsfRjY3i+5TPkkxr6La8M=";
    };

  nativeBuildInputs = [
    cmake
  ];

  cmakeFlags = [
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ];

  meta = with lib; {
    homepage = "https://github.com/marzer/tomlplusplus";
    description = "Header-only TOML config file parser and serializer for C++17";
    license = licenses.mit;
    pkgConfigModules = [ "tomlplusplus" ];
    platforms = platforms.all;
  };
}
