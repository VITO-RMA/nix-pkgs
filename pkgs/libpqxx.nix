{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  libpq,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "libpqxx" static stdenv;
  version = "7.10.1";

  src = fetchFromGitHub {
    owner = "jtv";
    repo = "libpqxx";
    rev = version;
    hash = "sha256-BVmIyJA5gDibwtmDvw7b300D0KdWv7c3Ytye6fiLAXU=";
  };

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    libpq
  ];

  propagatedBuildInputs = [
    libpq
  ];

  # Fix .pc file generation: use absolute paths instead of ${prefix}-relative ones.
  # When Nix sets CMAKE_INSTALL_*DIR to absolute store paths, the
  # "${prefix}/${CMAKE_INSTALL_LIBDIR}" pattern produces broken double-slash paths.
  postPatch = ''
    substituteInPlace src/CMakeLists.txt \
      --replace-fail \
        'set(libdir "''\\''${prefix}/''${CMAKE_INSTALL_LIBDIR}")' \
        'set(libdir "''${CMAKE_INSTALL_FULL_LIBDIR}")' \
      --replace-fail \
        'set(includedir "''\\''${prefix}/''${CMAKE_INSTALL_INCLUDEDIR}")' \
        'set(includedir "''${CMAKE_INSTALL_FULL_INCLUDEDIR}")'
  ''
  # libpq's auth code (SSPI/SCRAM) needs secur32 and crypt32 on Windows.  Add
  # them to the public Win32 link libs so they propagate to consumers (e.g.
  # weiss) through libpqxx's exported CMake target after libpq.a.
  + lib.optionalString stdenv.hostPlatform.isWindows ''
    substituteInPlace src/CMakeLists.txt \
      --replace-fail \
        'target_link_libraries(''${tgt} PUBLIC wsock32 ws2_32)' \
        'target_link_libraries(''${tgt} PUBLIC wsock32 ws2_32 secur32 crypt32)'
  '';

  cmakeFlags = [
    "-DSKIP_BUILD_TEST=ON"
    "-DBUILD_DOC=OFF"
    # Prefer config mode so libpq's PostgreSQLConfig.cmake (full link interface)
    # wins over CMake's bundled FindPostgreSQL.cmake (libpq.a only).
    "-DCMAKE_FIND_PACKAGE_PREFER_CONFIG=ON"
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ];

  # libpqxx's exported config re-resolves PostgreSQL at consumer-configure time
  # via find_dependency(PostgreSQL), which defaults to MODULE mode and picks
  # CMake's bundled FindPostgreSQL.cmake (libpq.a only).  Force CONFIG mode so
  # consumers (weiss) transparently get libpq's full, ordered link interface
  # (openssl, zlib, crypt32/secur32/ws2_32) without any project-side flags.
  postFixup = lib.optionalString stdenv.hostPlatform.isWindows ''
    cfg=$dev/lib/cmake/libpqxx/libpqxx-config.cmake
    if [ -f "$cfg" ]; then
      substituteInPlace "$cfg" \
        --replace-fail 'find_dependency(PostgreSQL)' 'find_dependency(PostgreSQL CONFIG REQUIRED)'
    fi
  '';

  strictDeps = true;

  meta = with lib; {
    changelog = "https://github.com/jtv/libpqxx/releases/tag/${version}";
    description = "C++ library to access PostgreSQL databases";
    downloadPage = "https://github.com/jtv/libpqxx";
    homepage = "https://pqxx.org/development/libpqxx/";
    license = licenses.bsd3;
    platforms = platforms.all;
  };
}
