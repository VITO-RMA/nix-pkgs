{
  lib,
  stdenv,
  libpng,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
}:

libpng.overrideAttrs (old: {
  buildInputs = old.buildInputs or [ ] ++ lib.optionals static [ zlib ];
  doCheck = false;

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
