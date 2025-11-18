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
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "proj";
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

  cmakeFlags = [
    "-DJSON_Diagnostics=OFF"
    "-DEXE_SQLITE3=${buildPackages.sqlite}/bin/sqlite3"
    "-DENABLE_CURL=OFF"
    "-DENABLE_TIFF=OFF"
    "-DBUILD_APPS=OFF"
  ]
  ++ (if static then [ "-DBUILD_SHARED_LIBS=OFF" ] else [ "-DBUILD_SHARED_LIBS=ON" ]);

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
    maintainers = with maintainers; [ dotlambda ];
    teams = [ teams.geospatial ];
    platforms = platforms.unix;
  };
})
