{
  lib,
  stdenv,
  sqlite,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
}:

sqlite.overrideAttrs (old: {
  buildInputs = [ zlib ];

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
