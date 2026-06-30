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
  useMemFile ? (stdenv.hostPlatform.config or "" != "x86_64-w64-mingw32"),
  mkPackageName,
}:

let
  # Use the provided TLS library (OpenSSL or LibreSSL) for MD5 when available.
  useOpenssl = openssl != null;
in
stdenv.mkDerivation rec {
  pname = mkPackageName "libxlsxwriter" static stdenv;
  version = "1.2.4";

  src = fetchFromGitHub {
    owner = "jmcnamara";
    repo = "libxlsxwriter";
    tag = "v${version}";
    hash = "sha256-mbi2jxxlXVyBTXkmSraZn6vMQAJ61PX2vwG10q2Ixos=";
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
  ]
  ++ lib.optionals useOpenssl [ openssl ];
  propagatedBuildInputs = buildInputs;

  cmakeFlags = [
    "-DUSE_SYSTEM_MINIZIP=1"
    "-DWINDOWSSTORE=OFF"
    "-DUSE_DTOA_LIBRARY=OFF"
    (lib.cmakeBool "USE_MEMFILE" useMemFile)
    (lib.cmakeBool "USE_OPENSSL_MD5" useOpenssl)
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ];

  meta = with lib; {
    description = "C library for creating Excel XLSX files";
    homepage = "https://libxlsxwriter.github.io/";
    changelog = "https://github.com/jmcnamara/libxlsxwriter/blob/${src.rev}/Changes.txt";
    license = licenses.bsd2;
    maintainers = with maintainers; [ dotlambda ];
    platforms = platforms.all;
  };
}
