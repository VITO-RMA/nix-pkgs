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
  version = "0.66";

  src = fetchFromGitHub {
    owner = "rbock";
    repo = "sqlpp11";
    rev = "${version}";
    sha256 = "sha256-dpBvcFjNhg4+9Trn00c5EPl59PvdezoLlZ4IM8fFYGo=";
  };

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
