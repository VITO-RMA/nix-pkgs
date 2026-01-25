{
  lib,
  stdenv,
  libpq,
  zlib,
  tzdata,
  openssl,
  windows,
  buildPackages,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

let
  buildPkgs = buildPackages;
  nativePkgs = buildPackages.buildPackages or buildPackages;
in
(libpq.override {
  inherit tzdata;
  inherit openssl;
  inherit zlib;
  bison = buildPkgs.bison;
  flex = buildPkgs.flex;
  makeWrapper = nativePkgs.makeWrapper;
  perl = buildPkgs.perl;
  pkg-config = buildPkgs.pkg-config;
  curlSupport = false;
  gssSupport = false;
  nlsSupport = false;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;

    doCheck = false;

    buildInputs =
      (old.buildInputs or [ ]) ++ lib.optionals stdenv.hostPlatform.isMinGW [ windows.pthreads ];

    NIX_LDFLAGS =
      (old.NIX_LDFLAGS or "") + lib.optionalString stdenv.hostPlatform.isWindows " -lcrypt32";

    # Apply single-linkage patch so we can select building only the static libpq and also disable libpq-refs-stamp
    # when not building the shared library.
    patches = (old.patches or [ ]) ++ [ ./patches/libpq-single-linkage.patch ];

    # Prefer static-only libpq when we're building a static variant.
    # This avoids building libpq.so and avoids the refs-stamp check which fails due to
    # undefined pthread_exit in the shared library graph.
    makeFlags = (old.makeFlags or [ ]) ++ lib.optionals static [ "LIBPQ_LIBRARY_TYPE=static" ];

    meta = old.meta // {
      platforms = lib.platforms.all;
    };
  })
