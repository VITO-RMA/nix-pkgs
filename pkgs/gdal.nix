{
  lib,
  stdenv,
  fetchFromGitHub,

  useMinimalFeatures ? true,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,

  useArmadillo ? (!useMinimalFeatures),
  useArrow ? (!useMinimalFeatures),
  useCBlosc ? (!useMinimalFeatures), # needed for zarr support
  useCurl ? (!useMinimalFeatures),
  useCryptopp ? (!useMinimalFeatures),
  useHDF ? (!useMinimalFeatures),
  useLibXml2 ? (!useMinimalFeatures),
  useExpat ? true, # XLSX support
  useSqlite ? true,
  useNetCDF ? (!useMinimalFeatures),
  usePostgres ? (!useMinimalFeatures),
  useQhull ? (!useMinimalFeatures),
  useTiledb ?
    (!useMinimalFeatures) && !(stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isx86_64),
  buildTools ? (!useMinimalFeatures),

  armadillo,
  arrow-cpp,
  bison,
  c-blosc,
  curl,
  cmake,
  cryptopp,
  expat,
  geos,
  hdf4,
  hdf5-cpp,
  json_c,
  lerc,
  libdeflate,
  libgeotiff,
  libiconv,
  libpq,
  libpng,
  libtiff,
  libxml2,
  lz4,
  netcdf,
  openssl,
  pcre2,
  pkg-config,
  proj,
  qhull,
  sqlite,
  tiledb,
  xz,
  zlib,
  zstd,
}:

let
  exts = stdenv.hostPlatform.extensions or { };
  ext =
    if static then
      (if stdenv.targetPlatform.isWindows then ".a" else exts.staticLibrary or ".a")
    else
      (exts.sharedLibrary or ".so");
in
stdenv.mkDerivation (finalAttrs: {
  pname = mkPackageName ("gdal" + lib.optionalString useMinimalFeatures "-minimal") static stdenv;
  #version = "3.12.0";
  version = "3.11.5";

  src = fetchFromGitHub {
    owner = "OSGeo";
    repo = "gdal";
    tag = "v${finalAttrs.version}";
    hash = "sha256-aVl4ofBaL3RYOBPkf5s9VJvddYuOC8QtaMruZfgpACU=";
  };

  nativeBuildInputs = [
    bison
    cmake
    pkg-config
  ];

  cmakeFlags = [
    "-DGDAL_USE_INTERNAL_LIBS=OFF"
    "-DGEOTIFF_INCLUDE_DIR=${lib.getDev libgeotiff}/include"
    "-DGEOTIFF_LIBRARY_RELEASE=${lib.getLib libgeotiff}/lib/libgeotiff${ext}"
    "-DBUILD_DOCS=OFF"
    "-DBUILD_PYTHON_BINDINGS=OFF"
    "-DBUILD_JAVA_BINDINGS=OFF"
    "-DGDAL_BUILD_OPTIONAL_DRIVERS=OFF"
    "-DOGR_BUILD_OPTIONAL_DRIVERS=OFF"
    "-DGDAL_USE_JPEG=OFF"
    "-DGDAL_USE_GIF=OFF"
    "-DGDAL_USE_PNG=OFF"
    "-DGDAL_USE_ZSTD=ON"
    "-DGDAL_USE_ZLIB=ON"
    "-DGDAL_USE_DEFLATE=ON"
    "-DGDAL_USE_LZMA=ON"
    "-DGDAL_USE_ARCHIVE=OFF"
    "-DGDAL_USE_SPATIALITE=OFF"
    "-DGDAL_ENABLE_DRIVER_AAIGRID=ON"
    "-DGDAL_ENABLE_DRIVER_GTIFF=ON"
    "-DGDAL_ENABLE_DRIVER_VRT=ON"
    "-DOGR_ENABLE_DRIVER_CSV=ON"

    (lib.cmakeBool "GDAL_USE_CURL" useCurl)
    (lib.cmakeBool "GDAL_USE_TILEDB" useTiledb)
    (lib.cmakeBool "GDAL_USE_BLOSC" useCBlosc)
    (lib.cmakeBool "GDAL_USE_CRYPTOPP" useCryptopp)
    (lib.cmakeBool "GDAL_USE_LIBXML2" useLibXml2)
    (lib.cmakeBool "GDAL_USE_QHULL" useQhull)
    (lib.cmakeBool "GDAL_USE_EXPAT" useExpat)
    (lib.cmakeBool "GDAL_ENABLE_DRIVER_NETCDF" useNetCDF)
    (lib.cmakeBool "OGR_ENABLE_DRIVER_XLSX" useExpat)
    (lib.cmakeBool "GDAL_USE_SQLITE3" useSqlite)
    (lib.cmakeBool "GDAL_USE_PCRE2" useSqlite) # pcre2 is only needed for the sqlite driver
    (lib.cmakeBool "OGR_ENABLE_DRIVER_GPKG" useSqlite)
    (lib.cmakeBool "BUILD_APPS" buildTools)
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ]
  ++ lib.optionals (stdenv.hostPlatform.isWindows && static) [
    # Force CMake to use the static iconv library instead of the dynamic one
    "-DIconv_INCLUDE_DIR=${lib.getDev libiconv}/include"
    "-DIconv_LIBRARY=${lib.getLib libiconv}/lib/libiconv.a"
    "-DIconv_CHARSET_LIBRARY=${lib.getLib libiconv}/lib/libcharset.a"
    "-DIconv_IS_BUILT_IN=FALSE"
  ]
  ++ lib.optionals stdenv.hostPlatform.isMusl [
    # Disable float16 support on musl since it lacks proper support
    "-DCMAKE_C_FLAGS=-DGDAL_DISABLE_FLOAT16"
    "-DHAVE_STD_FLOAT16_T:BOOL=OFF"
    "-DHAVE__FLOAT16=0"
  ]
  ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
    "-DCMAKE_SKIP_BUILD_RPATH=ON" # without, libgdal.so can't find libmariadb.so
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    "-DCMAKE_BUILD_WITH_INSTALL_NAME_DIR=ON"
  ];

  buildInputs =
    let
      tileDbDeps = lib.optionals useTiledb [ tiledb ];
      postgresDeps = lib.optionals usePostgres [ libpq ];
      arrowDeps = lib.optionals useArrow [ arrow-cpp ];
      curlDeps = lib.optionals useCurl [ curl ];
      hdfDeps = lib.optionals useHDF [
        hdf4
        hdf5-cpp
      ];
      netCdfDeps = lib.optionals useNetCDF [ netcdf ];
      armadilloDeps = lib.optionals useArmadillo [ armadillo ];
      libXml2Deps = lib.optionals useLibXml2 [ libxml2 ];
      expatDeps = lib.optionals useExpat [ expat ];
      sqliteDeps = lib.optionals useSqlite [
        sqlite
        pcre2
      ];
      cryptoppDeps = lib.optionals useCryptopp [ cryptopp ];
      qhullDeps = lib.optionals useQhull [ qhull ];
      cbloscDeps = lib.optionals useCBlosc [ c-blosc ];

      mingwDeps = lib.optionals stdenv.hostPlatform.isWindows [ libiconv ];
      darwinDeps = lib.optionals stdenv.hostPlatform.isDarwin [ libiconv ];
      nonDarwinDeps = lib.optionals (!stdenv.hostPlatform.isDarwin) [
        arrowDeps
      ];
    in
    [
      libgeotiff
      geos
      json_c
      lerc
      xz
      libdeflate
      libpng
      libtiff
      lz4
      openssl
      proj
      zlib
      zstd
    ]
    ++ expatDeps
    ++ tileDbDeps
    ++ postgresDeps
    ++ arrowDeps
    ++ curlDeps
    ++ hdfDeps
    ++ libXml2Deps
    ++ cbloscDeps
    ++ netCdfDeps
    ++ armadilloDeps
    ++ cryptoppDeps
    ++ sqliteDeps
    ++ qhullDeps
    ++ mingwDeps
    ++ darwinDeps
    ++ nonDarwinDeps;

  propagatedBuildInputs = finalAttrs.buildInputs;

  NIX_CFLAGS_COMPILE = lib.optionalString (
    stdenv.hostPlatform.isWindows && static && useSqlite
  ) "-DPCRE2_STATIC";
  NIX_CFLAGS_LINK = if static && stdenv.cc.isGNU then " -static-libgcc -static-libstdc++" else "";

  enableParallelBuilding = true;
  doInstallCheck = false;

  meta = with lib; {
    changelog = "https://github.com/OSGeo/gdal/blob/${finalAttrs.src.tag}/NEWS.md";
    description = "Translator library for raster geospatial data formats";
    homepage = "https://www.gdal.org/";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
})
