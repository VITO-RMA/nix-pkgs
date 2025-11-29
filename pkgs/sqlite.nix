{
  lib,
  stdenv,
  fetchurl,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  zlib,
  useZlib ? false,
  buildTools ? false,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "sqlite" static stdenv;
  version = "3.51.1";

  src = fetchurl {
    url = "https://sqlite.org/2025/sqlite-autoconf-3510100.tar.gz";
    hash = "sha256-TyRFzXBHlyTTKtAV7H/Tf7tvYTABO9S/vIDDK+tCt+A=";
  };

  patches = [
    ./patches/sqlite-add-config-include.patch
  ];

  postUnpack = ''
    cp ${./patches/sqlite-CMakeLists.txt} $sourceRoot/CMakeLists.txt
    cp ${./patches/sqlite3-nix-config.h.in} $sourceRoot/sqlite3-nix-config.h.in
    cp ${./patches/sqlite3.pc.in} $sourceRoot/sqlite3.pc.in
  '';

  nativeBuildInputs = [
    cmake
  ];

  buildInputs =
    let
      zlibDeps = lib.optionals useZlib [ zlib ];
    in
    [ ] ++ zlibDeps;

  transitiveBuildInputs = buildInputs;

  # if(VCPKG_LIBRARY_LINKAGE STREQUAL "dynamic")
  #     if(VCPKG_TARGET_IS_WINDOWS)
  #         set(SQLITE_API "__declspec(dllimport)")
  #     else()
  #         set(SQLITE_API "__attribute__((visibility(\"default\")))")
  #     endif()
  # else()
  #     set(SQLITE_API "")
  # endif()

  cmakeFlags = [
    "-DPKGCONFIG_VERSION=\"${version}\""
    "-DSQLITE_ENABLE_RTREE=ON"
    "-DSQLITE_ENABLE_GEOPOLY=ON"
    (lib.cmakeBool "WITH_ZLIB" useZlib)
  ]
  ++ [
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    (lib.cmakeBool "SQLITE3_SKIP_TOOLS" (!buildTools))
  ];

  meta = with lib; {
    changelog = "https://www.sqlite.org/releaselog/${lib.replaceStrings [ "." ] [ "_" ] version}.html";
    description = "Self-contained, serverless, zero-configuration, transactional SQL database engine";
    downloadPage = "https://sqlite.org/download.html";
    homepage = "https://www.sqlite.org/";
    license = licenses.publicDomain;
    mainProgram = "sqlite3";
    platforms = platforms.unix ++ platforms.windows;
    pkgConfigModules = [ "sqlite3" ];
  };
}
