{
  lib,
  stdenv,
  curl,
  openssl,
  zlib,
  zstd,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

curl.overrideAttrs (old: {
  pname = mkPackageName old.pname static stdenv;
  mingwSupport = false;

  buildInputs = [
    openssl
    zlib
    zstd
  ];

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
