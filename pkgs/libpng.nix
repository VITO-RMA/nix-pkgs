{
  lib,
  stdenv,
  libpng,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

let
  isMsvc =
    (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));
in
(libpng.override { apngSupport = false; }).overrideAttrs (old: rec {
  pname = mkPackageName old.pname static stdenv;
  buildInputs = [ zlib ];
  propagatedBuildInputs = buildInputs;

  doCheck = false;

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ]
    # The auxiliary tools (pngcp/pngfix/...) pull in POSIX headers such as
    # <unistd.h> that don't exist on the MSVC target; we only need the
    # library, so skip building the tools and tests there.
    ++ lib.optionals isMsvc [
      "--disable-tools"
      "--disable-tests"
    ];
})
