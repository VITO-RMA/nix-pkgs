{
  lib,
  stdenv,
  curl,
  openssl,
  zlib,
  zstd,
  static ? stdenv.hostPlatform.isStatic,
}:

curl.overrideAttrs (old: {
  buildInputs = (old.buildInputs or [ ]) ++ [
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
