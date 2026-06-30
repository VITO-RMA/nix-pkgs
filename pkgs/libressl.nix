{
  lib,
  stdenv,
  libressl,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

# LibreSSL is an OpenSSL-API-compatible TLS/crypto library that builds with
# CMake (unlike OpenSSL, whose native build relies on Configure/NMAKE and has
# no configuration for the MSVC ABI). That makes it usable as the OpenSSL
# provider for the MSVC cross target, where OpenSSL itself cannot be built.
(libressl.override {
  buildShared = !static;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;

    # Cross builds can't run the produced test binaries.
    doCheck = false;

    # The `openssl`/`ocspcheck` apps still build, but LibreSSL's CMake doesn't
    # build the `nc` (netcat) app on Windows, leaving its dedicated `nc` output
    # unproduced. Drop that output (and the postFixup step that moved `nc` into
    # it); the rest of the apps stay in `$bin`.
    outputs = [
      "bin"
      "dev"
      "out"
      "man"
    ];

    postFixup = ''
      moveToOutput "bin/openssl" "$bin"
      moveToOutput "bin/ocspcheck" "$bin"
    '';

    meta = old.meta // {
      platforms = lib.platforms.all;
    };
  })
