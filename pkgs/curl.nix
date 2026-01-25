{
  lib,
  stdenv,
  curl,
  openssl,
  zlib,
  zstd,
  brotli,
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

    buildInputs = [
      openssl
      zlib
      zstd
      brotli
    ];

    preConfigure =
      (old.preConfigure or "")
      + lib.optionalString static ''
        export PKG_CONFIG_ALL_STATIC=1
        export PKG_CONFIG="${stdenv.cc.targetPrefix}pkg-config --static"
      '';

    configureFlags =
      (old.configureFlags or [ ])
      ++ lib.optionals static [
        "--enable-static"
        "--disable-shared"
      ];
  })
