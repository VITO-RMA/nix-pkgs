{
  lib,
  stdenv,
  fetchFromGitHub,

  useMinimalFeatures ? true,
  static ? stdenv.hostPlatform.isStatic,

  useArmadillo ? (!useMinimalFeatures),
  useArrow ? (!useMinimalFeatures),
  useCBlosc ? (!useMinimalFeatures), # needed for zarr support
  useCurl ? (!useMinimalFeatures),
  useCryptopp ? (!useMinimalFeatures),
  useHDF ? (!useMinimalFeatures),
  useLibXml2 ? (!useMinimalFeatures),
  useNetCDF ? (!useMinimalFeatures),
  usePostgres ? (!useMinimalFeatures),
  useQhull ? (!useMinimalFeatures),
  useTiledb ?
    (!useMinimalFeatures) && !(stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isx86_64),

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

stdenv.mkDerivation (finalAttrs: {
  pname = "gdal" + lib.optionalString useMinimalFeatures "-minimal";
  #version = "3.12.0";
  version = "3.11.4";

  src = fetchFromGitHub {
    owner = "OSGeo";
    repo = "gdal";
    tag = "v${finalAttrs.version}";
    hash = "sha256-CFQF3vDhhXsAnIfUcn6oTQ4Xm+GH/36dqSGc0HvyEJ0=";
  };

  nativeBuildInputs = [
    bison
    cmake
    pkg-config
  ];

  cmakeFlags = [
    "-DGDAL_USE_INTERNAL_LIBS=OFF"
    "-DGEOTIFF_INCLUDE_DIR=${lib.getDev libgeotiff}/include"
    "-DGEOTIFF_LIBRARY_RELEASE=${lib.getLib libgeotiff}/lib/libgeotiff${
      if static then
        stdenv.hostPlatform.extensions.staticLibrary
      else
        stdenv.hostPlatform.extensions.sharedLibrary
    }"
    "-DBUILD_DOCS=OFF"
    "-DBUILD_PYTHON_BINDINGS=OFF"
    "-DBUILD_JAVA_BINDINGS=OFF"
    "-DGDAL_BUILD_OPTIONAL_DRIVERS=OFF"
    "-DOGR_BUILD_OPTIONAL_DRIVERS=OFF"
    "-DGDAL_USE_JPEG=OFF"
    "-DGDAL_USE_GIF=OFF"
    "-DGDAL_USE_PNG=OFF"
    "-DGDAL_USE_ZSTD=ON"
    # Both shouldn't be needed, but it depends on the order of findmodule calls
    "-Dzstd_DIR=${lib.getLib zstd}/lib/cmake/zstd"
    "-DZSTD_INCLUDE_DIR=${lib.getDev zstd}/include"
    "-DZSTD_LIBRARY=${lib.getLib zstd}/lib/libzstd${
      if static then
        stdenv.hostPlatform.extensions.staticLibrary
      else
        stdenv.hostPlatform.extensions.sharedLibrary
    }"
    "-DGDAL_USE_ZLIB=ON"
    "-DZLIB_INCLUDE_DIR=${lib.getDev zlib}/include"
    "-DZLIB_LIBRARY=${lib.getLib zlib}/lib/libz${
      if static then
        stdenv.hostPlatform.extensions.staticLibrary
      else
        stdenv.hostPlatform.extensions.sharedLibrary
    }"
    "-DGDAL_USE_DEFLATE=ON"
    "-DGDAL_USE_ARCHIVE=OFF"
    "-DGDAL_USE_SPATIALITE=OFF"
    "-DGDAL_ENABLE_DRIVER_AAIGRID=ON"
    "-DGDAL_ENABLE_DRIVER_GTIFF=ON"
    "-DGDAL_ENABLE_DRIVER_VRT=ON"
    "-DOGR_ENABLE_DRIVER_CSV=ON"
  ]
  ++ lib.optionals static [
    # rely on our specified lib paths to avoid picking up shared libs
    "-DCMAKE_DISABLE_FIND_PACKAGE_ZSTD=ON"
  ]
  ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
    "-DCMAKE_SKIP_BUILD_RPATH=ON" # without, libgdal.so can't find libmariadb.so
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    "-DCMAKE_BUILD_WITH_INSTALL_NAME_DIR=ON"
  ]
  ++ (if useCurl then [ "-DGDAL_USE_CURL=ON" ] else [ "-DGDAL_USE_CURL=OFF" ])
  ++ lib.optionals (!useCurl) [ "-DGDAL_USE_CURL=OFF" ]
  ++ lib.optionals (!useTiledb) [
    "-DGDAL_USE_TILEDB=OFF"
  ]
  ++ (if useCBlosc then [ "-DGDAL_USE_BLOSC=ON" ] else [ "-DGDAL_USE_BLOSC=OFF" ])
  ++ (if useCryptopp then [ "-DGDAL_USE_CRYPTOPP=ON" ] else [ "-DGDAL_USE_CRYPTOPP=OFF" ])
  ++ (if useLibXml2 then [ "-DGDAL_USE_LIBXML2=ON" ] else [ "-DGDAL_USE_LIBXML2=OFF" ])
  ++ (if useQhull then [ "-DGDAL_USE_QHULL=ON" ] else [ "-DGDAL_USE_QHULL=OFF" ])
  ++ (if static then [ "-DBUILD_SHARED_LIBS=OFF" ] else [ "-DBUILD_SHARED_LIBS=ON" ]);

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
      cryptoppDeps = lib.optionals useCryptopp [ cryptopp ];
      qhullDeps = lib.optionals useQhull [ qhull ];
      cbloscDeps = lib.optionals useCBlosc [ c-blosc ];

      darwinDeps = lib.optionals stdenv.hostPlatform.isDarwin [ libiconv ];
      nonDarwinDeps = lib.optionals (!stdenv.hostPlatform.isDarwin) [
        arrowDeps
      ];
    in
    [
      expat
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
      pcre2
      proj
      sqlite
      zlib
      zstd
    ]
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
    ++ qhullDeps
    ++ darwinDeps
    ++ nonDarwinDeps;

  propagatedBuildInputs = finalAttrs.buildInputs;

  NIX_CFLAGS_LINK = if static && stdenv.cc.isGNU then " -static-libgcc -static-libstdc++" else "";

  enableParallelBuilding = true;
  doInstallCheck = false;

  meta = with lib; {
    changelog = "https://github.com/OSGeo/gdal/blob/${finalAttrs.src.tag}/NEWS.md";
    description = "Translator library for raster geospatial data formats";
    homepage = "https://www.gdal.org/";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.unix;
  };
})
