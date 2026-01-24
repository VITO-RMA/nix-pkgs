{
  lib,
  stdenv,
  libpq,
  zlib,
  tzdata,
  openssl,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(libpq.override {
  inherit tzdata;
  inherit openssl;
  inherit zlib;
  curlSupport = false;
  gssSupport = false;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;

    doCheck = false;

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
