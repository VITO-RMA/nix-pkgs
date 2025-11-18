{
  lib,
  stdenv,
  openssl,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
}:

(openssl.override {
  static = static;
}).overrideAttrs
  (old: {
    buildInputs = old.buildInputs ++ lib.optionals static [ zlib ];
    doCheck = false;

    configureFlags =
      (old.configureFlags or [ ])
      ++ lib.optionals static [
        "no-shared"
        "no-module"
      ];
  })
