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
  (old: rec {
    pname = mkPackageName old.pname static stdenv;
    buildInputs = [ zlib ];
    propagatedBuildInputs = buildInputs;

    doCheck = false;

    outputs = lib.filter (o: o != "doc" && o != "man") (old.outputs or [ "out" ]);

    configureFlags =
      (old.configureFlags or [ ])
      ++ [
        "no-docs"
      ]
      ++ lib.optionals static [
        "no-shared"
        "no-module"
      ];
  })
