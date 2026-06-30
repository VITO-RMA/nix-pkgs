{
  lib,
  stdenv,
  openssl,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

let
  # OpenSSL has no build configuration for the MSVC ABI (its native VC build
  # relies on NMAKE), so it cannot be built as an MSVC-cross target. Opt out of
  # the MSVC package set; MSVC consumers use Schannel or skip OpenSSL instead.
  isMsvc =
    (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));
in
(openssl.override {
  static = static;
}).overrideAttrs
  (old: rec {
    pname = mkPackageName old.pname static stdenv;
    buildInputs = [ zlib ];
    propagatedBuildInputs = buildInputs;

    passthru = (old.passthru or { }) // {
      msvcSupport = !isMsvc;
    };

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
