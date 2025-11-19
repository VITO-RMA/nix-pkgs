{
  lib,
  stdenv,
  libpng,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
}:

libpng.overrideAttrs (old: {
  buildInputs = [ zlib ];
  doCheck = false;

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
