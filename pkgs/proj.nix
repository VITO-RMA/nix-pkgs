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
  version = "9.8.1";

  src = fetchFromGitHub {
    owner = "OSGeo";
    repo = "PROJ";
    rev = finalAttrs.version;
    hash = "sha256-sOAxWihgU1TAMWcju5LN4cPenHHoGgd4oYJ4HA3F/Ks=";
  };

  patches = [
    ./patches/proj-libtiff.patch
    ./patches/proj-mingw-deps.patch
  ]
  ++ lib.optionals (stdenv.hostPlatform.isMinGW || (stdenv.cc.isZig or false)) [
    ./patches/proj-pkgconfig.patch
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

  # Cross builds skip installCheckPhase. Only link this C consumer here;
  # pkg-config must supply the C++ runtime, and no Windows binary is run.
  postInstall = lib.optionalString stdenv.hostPlatform.isMinGW ''
    export PKG_CONFIG_PATH="$out/lib/pkgconfig:$PKG_CONFIG_PATH"
    cat > pkgconfig-check.c <<'EOF'
    #include <proj.h>
    int main(void) {
        PJ_CONTEXT *ctx = proj_context_create();
        PJ *crs = proj_create(ctx, "EPSG:4326");
        proj_destroy(crs);
        proj_context_destroy(ctx);
        return 0;
    }
    EOF
    $CC pkgconfig-check.c -o pkgconfig-check.exe $($PKG_CONFIG --cflags --libs --static proj)
  '';

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
