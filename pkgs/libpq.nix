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

  # Single output: PostgreSQL's meson install cross-references between lib (pc
  # libdir=out) and headers (includedir=dev), which creates an out<->dev
  # reference cycle.  Keep everything in one output to avoid it.
  outputs = [ "out" ];

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
  + lib.optionalString (static && stdenv.hostPlatform.isWindows) ''
    pushd $out/lib
    printf 'create libpq_merged.a\naddlib libpq.a\naddlib libpgcommon.a\naddlib libpgport.a\nsave\nend\n' | "$AR" -M
    mv libpq_merged.a libpq.a
    "$RANLIB" libpq.a
    popd
  ''
  # PostgreSQL's meson build ships no CMake config, so consumers fall back to
  # CMake's bundled FindPostgreSQL.cmake, which exposes only libpq.a and ignores
  # libpq.pc -- losing openssl/zlib and (on Windows) secur32/crypt32/ws2_32.
  # Ship a real PostgreSQLConfig.cmake defining PostgreSQL::PostgreSQL with the
  # full, correctly ordered link interface so config mode propagates everything.
  + lib.optionalString (static && stdenv.hostPlatform.isWindows) ''
    mkdir -p $out/lib/cmake/PostgreSQL
    deps="${openssl.out or openssl}/lib/libssl.a;${openssl.out or openssl}/lib/libcrypto.a;${zlib.out or zlib}/lib/libz.a"
    ${lib.optionalString stdenv.hostPlatform.isWindows ''deps="$deps;crypt32;secur32;ws2_32;gdi32"''}
    cat > $out/lib/cmake/PostgreSQL/PostgreSQLConfig.cmake <<CMAKE
    set(PostgreSQL_FOUND TRUE)
    set(PostgreSQL_VERSION_STRING "18.4")
    set(PostgreSQL_INCLUDE_DIRS "$out/include")
    set(PostgreSQL_LIBRARY_DIRS "$out/lib")
    set(PostgreSQL_LIBRARIES "$out/lib/libpq.a;$deps")
    set(PostgreSQL_INCLUDE_DIR "$out/include")
    set(PostgreSQL_LIBRARY "$out/lib/libpq.a")
    set(PostgreSQL_TYPE_INCLUDE_DIR "$out/include")
    if(NOT TARGET PostgreSQL::PostgreSQL)
      add_library(PostgreSQL::PostgreSQL STATIC IMPORTED)
      set_target_properties(PostgreSQL::PostgreSQL PROPERTIES
        IMPORTED_LOCATION "$out/lib/libpq.a"
        INTERFACE_INCLUDE_DIRECTORIES "$out/include"
        INTERFACE_LINK_LIBRARIES "$deps")
    endif()
    CMAKE
    cat > $out/lib/cmake/PostgreSQL/PostgreSQLConfigVersion.cmake <<CMAKE
    set(PACKAGE_VERSION "18.4")
    set(PACKAGE_VERSION_COMPATIBLE TRUE)
    if("\''${PACKAGE_FIND_VERSION}" STREQUAL "18.4")
      set(PACKAGE_VERSION_EXACT TRUE)
    endif()
    CMAKE
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
