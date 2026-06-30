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

let
  isMsvc =
    (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));
in
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

  # Fix /usr/bin/env shebangs that don't exist in the Nix build sandbox.
  # For MSVC: Windows SDK import libs (ws2_32, secur32) aren't in clang's
  # built-in search dirs (-print-search-dirs), so Meson's find_library can't
  # find them (neither filesystem search nor link test works in cross mode).
  # Add the SDK lib dir via the `dirs:` parameter.
  postPatch = ''
    patchShebangs src/tools/
  ''
  + lib.optionalString isMsvc ''
    substituteInPlace meson.build \
      --replace-fail \
        "cc.find_library('ws2_32', required: true)" \
        "cc.find_library('ws2_32', required: true, dirs: ['${windows.sdk}/sdk/lib/um/x64'])" \
      --replace-fail \
        "cc.find_library('secur32', required: true)" \
        "cc.find_library('secur32', required: true, dirs: ['${windows.sdk}/sdk/lib/um/x64'])"
    # Clang's <tgmath.h> is incompatible with UCRT's struct-based complex.
    substituteInPlace meson.build \
      --replace-fail "#include <complex.h>" "/* #include <complex.h> */" \
      --replace-fail "#include <tgmath.h>" "/* #include <tgmath.h> */"
    # Our toolchain is clang with the GNU driver targeting the MSVC ABI.
    # _MSC_VER IS defined (1933), so C code paths are correct. But meson's
    # cc.get_id() returns 'clang' not 'msvc', so Windows/MSVC build-system
    # paths are skipped. Selectively patch the checks we need:
    #  - Skip -D_POSIX_C_SOURCE (wrong for MSVC target)
    #  - Use MSVC module/export naming (.lib not lib*.a)
    #  - Include win32_msvc compat headers (dirent.h, unistd.h replacements)
    # But NOT the /wd, /D, /INCREMENTAL, /STACK flags blocks — those are
    # cl.exe syntax that the GNU clang driver doesn't understand.
    sed -i \
      -e "/library_path_var/,/endif/{s|if cc.get_id() != 'msvc'|if cc.get_id() != 'msvc' and cc.get_define('_MSC_VER') == '''|}" \
      -e "/export_file_suffix/,/mod_link_with_dir/{s|if cc.get_id() == 'msvc'|if cc.get_id() == 'msvc' or cc.get_define('_MSC_VER') != '''|}" \
      -e "/port\/win32'/,/endif/{s|if cc.get_id() == 'msvc'|if cc.get_id() == 'msvc' or cc.get_define('_MSC_VER') != '''|}" \
      meson.build
    # The MinGW else branch uses GNU ld flags (-Wl,--stack etc.) that
    # lld-link does not understand.  Replace with lld-link equivalents.
    substituteInPlace meson.build \
      --replace-fail \
        "ldflags += '-Wl,--stack,@0@'.format(cdata.get('WIN32_STACK_RLIMIT'))" \
        "ldflags += '-Wl,/STACK:@0@'.format(cdata.get('WIN32_STACK_RLIMIT'))" \
      --replace-fail \
        "ldflags += '-Wl,--allow-multiple-definition'" \
        "ldflags += '-Wl,/FORCE:MULTIPLE'" \
      --replace-fail \
        "ldflags += '-Wl,--disable-auto-import'" \
        "# --disable-auto-import not needed for lld-link"
    # Clang targeting MSVC does NOT define __GNUC__, so c.h picks the
    # __declspec(align(a)) form of pg_attribute_aligned.  That form can't
    # appear after a declarator name, breaking the int128 typedefs.
    # Add __clang__ to the __GNUC__ guard so we get __attribute__((aligned(a))).
    substituteInPlace src/include/c.h \
      --replace-fail \
        '#if defined(__GNUC__) || defined(__SUNPRO_C)' \
        '#if defined(__GNUC__) || defined(__SUNPRO_C) || defined(__clang__)'
    # PostgreSQL's pg_bitutils.h includes <intrin.h> under _MSC_VER, but
    # clang's <intrin.h> internally includes <cpuid.h> (GCC-compat) which
    # defines __cpuid as a 5-arg macro, conflicting with the MSVC-style
    # void __cpuid(int[4], int) declaration.  Our clang has __builtin_ctz
    # and __builtin_clz, so just use the GCC path.
    substituteInPlace src/include/port/pg_bitutils.h \
      --replace-fail \
        '#ifdef _MSC_VER' \
        '#if defined(_MSC_VER) && !defined(__clang__)'
    # src/port/meson.build gates dirent.c and win32gettimeofday.c behind
    # cc.get_id() == 'msvc'.  We need these for UCRT (no gettimeofday).
    substituteInPlace src/port/meson.build \
      --replace-fail \
        "if cc.get_id() == 'msvc'" \
        "if cc.get_id() == 'msvc' or cc.get_define('_MSC_VER') != '''"
  '';

  env.NIX_LDFLAGS = lib.optionalString stdenv.hostPlatform.isWindows "-lcrypt32";

  # -DUSE_PRIVATE_ENCODING_FUNCS causes undefined reference to pg_encoding_to_char
  # when linking against libpq.a.  The upstream reasoning (avoid loading a mismatched
  # libpq.so in initdb) does not apply with Nix store paths.
  env.NIX_CFLAGS_COMPILE =
    "-UUSE_PRIVATE_ENCODING_FUNCS"
    + lib.optionalString isMsvc " -D_CRT_SECURE_NO_DEPRECATE -D_CRT_NONSTDC_NO_DEPRECATE -DWIN32 -DWINDOWS -D__WINDOWS__ -D__WIN32__";

  mesonAutoFeatures = "disabled";

  mesonFlags = [
    (if static then "-Ddefault_library=static" else "-Ddefault_library=shared")
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
