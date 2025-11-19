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
    buildInputs = [ zlib ];
    doCheck = false;
    withDocs = false;

    configureFlags =
      (old.configureFlags or [ ])
      ++ lib.optionals static [
        "no-shared"
        "no-module"
      ];
  })
