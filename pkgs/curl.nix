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

(curl.override {
  inherit openssl;
  inherit zlib;
  inherit zstd;
  inherit brotli;
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
      openssl
      zlib
      zstd
      brotli
    ];

    # Drop autotools configure flags/phases – we use CMake now.
    configureFlags = [ ];
    preConfigure = "";

    cmakeFlags = [
      "-DBUILD_TESTING=OFF"
      "-DBUILD_CURL_EXE=OFF"
      "-DENABLE_CURL_MANUAL=OFF"
      "-DSHARE_LIB_OBJECT=OFF"
      "-DCURL_USE_OPENSSL=ON"
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
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    ]
    ++ lib.optionals stdenv.hostPlatform.isWindows [
      "-DENABLE_UNICODE=ON"
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
