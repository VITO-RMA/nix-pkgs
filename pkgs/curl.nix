{
  lib,
  stdenv,
  curl,
  openssl,
  zlib,
  zstd,
  brotli,
  cmake,
  pkg-config,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

let
  # OpenSSL has no build configuration for the MSVC ABI (its VC build relies on
  # NMAKE), so it can't be depended on for MSVC targets. Use the OS-provided
  # Schannel TLS backend there instead. MinGW and other platforms keep OpenSSL.
  isMsvc =
    (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));
  useOpenssl = !isMsvc;
in
(curl.override {
  inherit openssl;
  inherit zlib;
  inherit zstd;
  inherit brotli;
  opensslSupport = useOpenssl;
  c-aresSupport = false;
  http2Support = false;
  http3Support = false;
  gssSupport = false;
  pslSupport = false;
  scpSupport = false;
  idnSupport = false;
  ldapSupport = false;
  rtmpSupport = false;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;

    nativeBuildInputs = [
      cmake
      pkg-config
    ];

    buildInputs = [
      zlib
      zstd
      brotli
    ]
    ++ lib.optionals useOpenssl [ openssl ];

    # Drop autotools configure flags/phases – we use CMake now.
    configureFlags = [ ];
    preConfigure = "";

    cmakeFlags = [
      "-DBUILD_TESTING=OFF"
      "-DBUILD_CURL_EXE=OFF"
      "-DENABLE_CURL_MANUAL=OFF"
      "-DSHARE_LIB_OBJECT=OFF"
      "-DCURL_BROTLI=ON"
      "-DCURL_ZSTD=ON"
      "-DCURL_USE_LIBPSL=OFF"
      "-DCURL_USE_LIBSSH2=OFF"
      "-DENABLE_ARES=OFF"
      "-DUSE_NGHTTP2=OFF"
      "-DUSE_NGTCP2=OFF"
      "-DCURL_USE_GSSAPI=OFF"
      "-DCURL_DISABLE_LDAP=ON"
      "-DCURL_DISABLE_LDAPS=ON"
      "-DUSE_LIBIDN2=OFF"
      "-DCURL_USE_RTMP=OFF"
      "-DCURL_USE_CMAKECONFIG=ON"
      "-DCURL_USE_PKGCONFIG=ON"
      (lib.cmakeBool "CURL_USE_OPENSSL" useOpenssl)
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    ]
    ++ lib.optionals stdenv.hostPlatform.isWindows [
      "-DENABLE_UNICODE=ON"
    ]
    ++ lib.optionals isMsvc [
      "-DCURL_USE_SCHANNEL=ON"
    ];

    # Ensure CMake pkg-config calls resolve static deps in cross builds.
    preBuild = lib.optionalString static ''
      export PKG_CONFIG_ALL_STATIC=1
    '';

    # The upstream derivation expects 'bin' and 'devdoc' outputs.
    # Since we don't build the executable or docs, create placeholders.
    postInstall = (old.postInstall or "") + ''
      mkdir -p $bin $devdoc $man
    '';
  })
