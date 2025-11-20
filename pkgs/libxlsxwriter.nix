{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  minizip,
  zlib,
  openssl ? null,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "libxlsxwriter" static stdenv;
  version = "1.2.3";

  src = fetchFromGitHub {
    owner = "jmcnamara";
    repo = "libxlsxwriter";
    tag = "v${version}";
    hash = "sha256-1FUJLsnx0ZNTT66sK7/gbZVo6Se85nbYvtEyoxeOHTI=";
  };

  patchPhase = ''
    rm -rfv third_party/minizip
  '';

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    minizip
    zlib
    openssl
  ];

  cmakeFlags = [
    "-DUSE_SYSTEM_MINIZIP=1"
    "-DWINDOWSSTORE=OFF"
    "-DUSE_DTOA_LIBRARY=OFF"
    "-DUSE_MEM_FILE=ON"
    "-DUSE_OPENSSL_MD5=ON"
  ]
  ++ [ (lib.cmakeBool "USE_OPENSSL_MD5" (openssl != null)) ]
  ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];

  meta = with lib; {
    description = "C library for creating Excel XLSX files";
    homepage = "https://libxlsxwriter.github.io/";
    changelog = "https://github.com/jmcnamara/libxlsxwriter/blob/${src.rev}/Changes.txt";
    license = licenses.bsd2;
    maintainers = with maintainers; [ dotlambda ];
    platforms = platforms.unix;
  };
}
