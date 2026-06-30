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
  useCryptopp ? (
    !useMinimalFeatures && !(stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
  ),
  useHDF ? (!useMinimalFeatures),
  useLibXml2 ? (!useMinimalFeatures),
  useExpat ? true, # XLSX support
  useSqlite ? true,
  useFreexl ? (!useMinimalFeatures), # XLS support
  useNetCDF ? (!useMinimalFeatures),
  usePostgres ? (!useMinimalFeatures),
  useQhull ? (!useMinimalFeatures),
  buildTools ? (!useMinimalFeatures),
  buildMinimalTools ? false,
  useGrib ? (!useMinimalFeatures),
  usePcRaster ? (!useMinimalFeatures),

  armadillo,
  arrow-cpp,
  bison,
  c-blosc,
  curl,
  cmake,
  cryptopp,
  expat,
  freexl,
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
  xz,
  zlib,
  zstd,
}:

let
  isMsvc =
    (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));
  exts = stdenv.hostPlatform.extensions or { };
  ext =
    if static then
      (
        if isMsvc then
          ".lib"
        else if stdenv.targetPlatform.isWindows then
          ".a"
        else
          exts.staticLibrary or ".a"
      )
    else
      (exts.sharedLibrary or ".so");
  # MSVC static libs have no "lib" prefix (foo.lib), MinGW/Unix use "lib" (libfoo.a)
  libPrefix = if isMsvc then "" else "lib";
in
stdenv.mkDerivation (finalAttrs: {
  pname = mkPackageName ("gdal" + lib.optionalString useMinimalFeatures "-minimal") static stdenv;
  version = "3.12.4";

  src = fetchFromGitHub {
    owner = "OSGeo";
    repo = "gdal";
    tag = "v${finalAttrs.version}";
    hash = "sha256-sD/ZAOvMWK2+AGw6wgziDsheH+hwUwhd7i2f65cjFKg=";
  };

  patches = [ ];

  postPatch = lib.optionalString static ''
    # Make gdal use freexl's installed config (FreeXLConfig.cmake)
    rm cmake/modules/packages/FindFreeXL.cmake
  '';

  nativeBuildInputs = [
    bison
    cmake
    pkg-config
  ];

  cmakeFlags = [
    "-DGDAL_USE_INTERNAL_LIBS=OFF"
    "-DGEOTIFF_INCLUDE_DIR=${lib.getDev libgeotiff}/include"
    "-DGEOTIFF_LIBRARY_RELEASE=${lib.getLib libgeotiff}/lib/${libPrefix}geotiff${ext}"
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
    (lib.cmakeBool "GDAL_USE_BLOSC" useCBlosc)
    (lib.cmakeBool "GDAL_USE_CRYPTOPP" useCryptopp)
    (lib.cmakeBool "GDAL_USE_LIBXML2" useLibXml2)
    (lib.cmakeBool "GDAL_USE_QHULL" useQhull)
    (lib.cmakeBool "GDAL_USE_EXPAT" useExpat)
    (lib.cmakeBool "GDAL_ENABLE_DRIVER_PCRASTER" usePcRaster)
    (lib.cmakeBool "GDAL_ENABLE_DRIVER_NETCDF" useNetCDF)
    (lib.cmakeBool "GDAL_ENABLE_DRIVER_GRIB" useGrib)
    (lib.cmakeBool "OGR_ENABLE_DRIVER_XLSX" useExpat)
    (lib.cmakeBool "OGR_ENABLE_DRIVER_XLS" useFreexl)
    (lib.cmakeBool "GDAL_USE_SQLITE3" useSqlite)
    (lib.cmakeBool "GDAL_USE_PCRE2" useSqlite) # pcre2 is only needed for the sqlite driver
    (lib.cmakeBool "OGR_ENABLE_DRIVER_GPKG" useSqlite)
    (lib.cmakeBool "BUILD_APPS" buildTools)
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
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
  ]
  ++ lib.optionals isMsvc [
    # libc++.lib and libcmt.lib both define std::nothrow; allow the duplicate
    "-DCMAKE_EXE_LINKER_FLAGS=-Wl,/FORCE:MULTIPLE"
    # CryptoPP's try_compile link test fails in cross mode (std::nothrow dup);
    # the actual library works fine, so skip the test.
    "-DCRYPTOPP_TEST_KNOWNBUG:BOOL=TRUE"
    # LibreSSL's .lib files are in the non-dev output, but CMake's FindOpenSSL
    # only searches CMAKE_PREFIX_PATH (= dev output with no .lib files).
    # Point it at the correct library locations explicitly.
    "-DOPENSSL_ROOT_DIR=${lib.getLib openssl}"
    "-DOPENSSL_CRYPTO_LIBRARY=${lib.getLib openssl}/lib/crypto.lib"
    "-DOPENSSL_SSL_LIBRARY=${lib.getLib openssl}/lib/ssl.lib"
  ]
  ++ lib.optionals (isMsvc && static) [
    # liblzma headers use __declspec(dllimport) unless LZMA_API_STATIC is set
    "-DCMAKE_C_FLAGS_INIT=-DLZMA_API_STATIC"
    "-DCMAKE_CXX_FLAGS_INIT=-DLZMA_API_STATIC"
    # __int128 compiles with clang but compiler-rt for MSVC lacks __floatuntidf
    "-DINT128_FOUND:BOOL=FALSE"
    "-DHAVE_UINT128_T:BOOL=FALSE"
  ];

  CXXFLAGS = [
    "-DNOMINMAX"
  ];

  buildInputs =
    let
      postgresDeps = lib.optionals usePostgres [ libpq ];
      arrowDeps = lib.optionals (useArrow && !stdenv.hostPlatform.isDarwin) [ arrow-cpp ];
      curlDeps = lib.optionals useCurl [ curl ];
      hdfDeps = lib.optionals useHDF [
        hdf4
        hdf5-cpp
      ];
      netCdfDeps = lib.optionals useNetCDF [ netcdf ];
      armadilloDeps = lib.optionals useArmadillo [ armadillo ];
      libXml2Deps = lib.optionals useLibXml2 [ libxml2 ];
      expatDeps = lib.optionals useExpat [ expat ];
      freexlDeps = lib.optionals useFreexl [ freexl ];
      sqliteDeps = lib.optionals useSqlite [
        sqlite
        pcre2
      ];
      cryptoppDeps = lib.optionals useCryptopp [ cryptopp ];
      qhullDeps = lib.optionals useQhull [ qhull ];
      cbloscDeps = lib.optionals useCBlosc [ c-blosc ];

      mingwDeps = lib.optionals stdenv.hostPlatform.isWindows [ libiconv ];
      darwinDeps = lib.optionals stdenv.hostPlatform.isDarwin [ libiconv ];

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
    ++ freexlDeps
    ++ expatDeps
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
    ++ darwinDeps;

  propagatedBuildInputs = finalAttrs.buildInputs;

  enableParallelBuilding = true;
  doInstallCheck = false;

  postInstall = lib.optionalString (buildTools && buildMinimalTools) ''
    for f in "$out/bin/"*; do
      case "$(basename "$f")" in
        gdal_translate|gdalwarp|gdal_translate.exe|gdalwarp.exe) ;;
        *) rm -f "$f" ;;
      esac
    done
  '';

  meta = with lib; {
    changelog = "https://github.com/OSGeo/gdal/blob/${finalAttrs.src.tag}/NEWS.md";
    description = "Translator library for raster geospatial data formats";
    homepage = "https://www.gdal.org/";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
})
