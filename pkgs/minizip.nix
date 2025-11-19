{
  lib,
  stdenv,
  minizip,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
}:

minizip.overrideAttrs (old: {
  buildInputs = [ zlib ];
  doCheck = false;

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
