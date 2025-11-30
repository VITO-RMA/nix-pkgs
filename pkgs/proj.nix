{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  buildPackages,
  sqlite,
  testers,
  static ? stdenv.hostPlatform.isStatic,
  embed-data ? true,
  mkPackageName,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = mkPackageName "proj" static stdenv;
  version = "9.7.0";

  src = fetchFromGitHub {
    owner = "OSGeo";
    repo = "PROJ";
    rev = finalAttrs.version;
    hash = "sha256-Vdznj9WGuws1p+owDNHlVERjOM3fS1+RBtqe01q500E=";
  };

  patches = [
    ./patches/proj-libtiff.patch
  ];

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [
    sqlite
  ];

  propagatedBuildInputs = finalAttrs.buildInputs;

  cmakeFlags = [
    "-DJSON_Diagnostics=OFF"
    "-DEXE_SQLITE3=${buildPackages.sqlite}/bin/sqlite3"
    "-DENABLE_CURL=OFF"
    "-DENABLE_TIFF=OFF"
    "-DBUILD_APPS=OFF"
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    (lib.cmakeBool "EMBED_RESOURCE_FILES" embed-data)
    (lib.cmakeBool "USE_ONLY_EMBEDDED_RESOURCE_FILES" embed-data)
  ];

  CXXFLAGS = [
    # GCC 13: error: 'int64_t' in namespace 'std' does not name a type
    "-include cstdint"
  ];

  preCheck =
    let
      libPathEnvVar = if stdenv.hostPlatform.isDarwin then "DYLD_LIBRARY_PATH" else "LD_LIBRARY_PATH";
    in
    ''
      export HOME=$TMPDIR
      export TMP=$TMPDIR
      export ${libPathEnvVar}=$PWD/lib
    '';

  doCheck = false;

  passthru = {
    inherit sqlite;
    tests.pkg-config = testers.testMetaPkgConfig finalAttrs.finalPackage;
  };

  meta = with lib; {
    changelog = "https://github.com/OSGeo/PROJ/blob/${finalAttrs.src.rev}/NEWS.md";
    description = "Cartographic Projections Library";
    homepage = "https://proj.org/";
    license = licenses.mit;
    pkgConfigModules = [
      "proj"
    ];
    platforms = platforms.all;
  };
})
