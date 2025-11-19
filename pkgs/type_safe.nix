{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
}:

stdenv.mkDerivation rec {
  pname = "type_safe";
  version = "v0.2.4";

  src = fetchFromGitHub {
    owner = "foonathan";
    repo = "type_safe";
    rev = version;
    sha256 = "sha256-z8muv/fl7+7NEZly/CHlBqjy4mIjnWRPSxxVIXp6ZGE=";
  };

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
    platforms = platforms.unix;
    license = licenses.mit;
    maintainers = [ ];
  };
}
