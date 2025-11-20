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
