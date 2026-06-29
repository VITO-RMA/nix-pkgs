{
  lib,
  stdenv,
  fetchFromGitHub,
  zlib,
  openssl,
  tzdata,
  windows,
  buildPackages,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

stdenv.mkDerivation {
  pname = mkPackageName "libpq" static stdenv;
  version = "18.4";

  src = fetchFromGitHub {
    owner = "postgres";
    repo = "postgres";
    rev = "refs/tags/REL_18_4";
    hash = "sha256-Ac/Dqcj8vjcW3my5vsnKaMiQqTq/HPtUzckJ3SMyrfA=";
  };

  outputs =
    if static then
      [ "out" ]
    else
      [
        "out"
        "dev"
      ];

  nativeBuildInputs = [
    buildPackages.meson
    buildPackages.ninja
    buildPackages.pkg-config
    buildPackages.bison
    buildPackages.flex
    buildPackages.perl
    buildPackages.python3
  ];

  buildInputs = [
    zlib
    openssl
  ]
  ++ lib.optionals stdenv.hostPlatform.isMinGW [ windows.pthreads ];

  patches = [
    # vcpkg patches for correct static/shared library linkage with meson
    ./patches/libpq-library-linkage.diff
    ./patches/libpq-client-tools.diff
  ];

  # Fix /usr/bin/env shebangs that don't exist in the Nix build sandbox
  postPatch = ''
    patchShebangs src/tools/
  '';

  env.NIX_LDFLAGS = lib.optionalString stdenv.hostPlatform.isWindows "-lcrypt32";

  # -DUSE_PRIVATE_ENCODING_FUNCS causes undefined reference to pg_encoding_to_char
  # when linking against libpq.a.  The upstream reasoning (avoid loading a mismatched
  # libpq.so in initdb) does not apply with Nix store paths.
  env.NIX_CFLAGS_COMPILE = "-UUSE_PRIVATE_ENCODING_FUNCS";

  mesonAutoFeatures = "disabled";

  mesonFlags = [
    "-Ddefault_library=${if static then "static" else "shared"}"
    "-Dssl=openssl"
    "-Dzlib=enabled"
    "-Dtools=disabled"
    "-Dsystem_tzdata=${tzdata}/share/zoneinfo"
  ]
  ++ lib.optionals static [
    "-Dprefer_static=true"
  ];

  doCheck = false;

  postInstall = ''
    rm -rf $out/share
  ''
  # For static builds, libpq.a is not self-contained: it references symbols
  # (pg_encoding_to_char, pg_sprintf, strlcpy, pg_strong_random, scram_*, ...)
  # that live in libpgcommon.a and libpgport.a.  The .pc file lists these in
  # Libs, but downstream consumers that link libpq.a via CMake (e.g. libpqxx)
  # only pick up -lpq, producing undefined references.  Merge the support
  # libraries into libpq.a so it stands on its own.
  + lib.optionalString static ''
    pushd $out/lib
    printf 'create libpq_merged.a\naddlib libpq.a\naddlib libpgcommon.a\naddlib libpgport.a\nsave\nend\n' | "$AR" -M
    mv libpq_merged.a libpq.a
    "$RANLIB" libpq.a
    popd
  '';

  meta = {
    description = "C application programmer's interface to PostgreSQL";
    homepage = "https://www.postgresql.org/";
    changelog = "https://www.postgresql.org/docs/release/18.4/";
    license = lib.licenses.postgresql;
    platforms = lib.platforms.all;
    pkgConfigModules = [ "libpq" ];
  };
}
