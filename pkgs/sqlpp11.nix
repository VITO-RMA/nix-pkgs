{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  withSqlite ? true,
  sqlite3 ? null,
  howard-hinnant-date,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "sqlpp11" static stdenv;
  version = "v0.65";

  src = fetchFromGitHub {
    owner = "rbock";
    repo = "sqlpp11";
    rev = "38e9c7efd424a0e358244e410d0426423956897d";
    sha256 = "sha256-LFOIFaNqFgqEI1eVrgING+zm32l0t8yQx0ozaiOTkhw=";
  };

  patches = [
    #./patches/sqlpp11-ciso646.patch
  ];

  nativeBuildInputs = [
    cmake
  ];

  buildInputs =
    let
      sqliteDeps = lib.optionals withSqlite [ sqlite3 ];
    in
    [ howard-hinnant-date ] ++ sqliteDeps;

  propagatedBuildInputs = buildInputs;

  cmakeFlags = [
    "-DBUILD_TESTING:BOOL=OFF"
    "-DUSE_SYSTEM_DATE:BOOL=ON"
    "-DTYPE_SAFE_BUILD_TEST_EXAMPLE=OFF"
    "-DBUILD_MARIADB_CONNECTOR=OFF"
    "-DBUILD_MYSQL_CONNECTOR=OFF"
    "-DBUILD_POSTGRESQL_CONNECTOR=OFF"
    "-Ddate_DIR=${lib.getLib howard-hinnant-date}/lib/cmake"
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    (lib.cmakeBool "BUILD_SQLITE3_CONNECTOR" withSqlite)
  ]
  ++ [ ];

  meta = with lib; {
    homepage = "https://github.com/rbock/sqlpp11";
    description = "A type safe SQL template library for C++ ";
    platforms = platforms.all;
    license = licenses.bsd2;
  };
}
