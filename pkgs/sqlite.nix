{
  lib,
  stdenv,
  sqlite,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
}:

sqlite.overrideAttrs (old: {
  buildInputs = old.buildInputs ++ lib.optionals static [ zlib ];

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
