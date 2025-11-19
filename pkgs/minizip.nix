{
  lib,
  stdenv,
  minizip,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
}:

minizip.overrideAttrs (old: {
  buildInputs = old.buildInputs or [ ] ++ [ zlib ];
  doCheck = false;

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
