{
  lib,
  stdenv,
  openssl,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(openssl.override {
  static = static;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
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
