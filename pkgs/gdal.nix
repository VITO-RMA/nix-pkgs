{
  lib,
  stdenv,
  fetchFromGitHub,

  useMinimalFeatures ? true,
  static ? stdenv.hostPlatform.isStatic,

  useArmadillo ? (!useMinimalFeatures),
  useArrow ? (!useMinimalFeatures),
  useHDF ? (!useMinimalFeatures),
  useNetCDF ? (!useMinimalFeatures),
  usePostgres ? (!useMinimalFeatures),
  useTiledb ?
    (!useMinimalFeatures) && !(stdenv.hostPlatform.isDarwin && stdenv.hostPlatform.isx86_64),

  armadillo,
  arrow-cpp,
  bison,
  c-blosc,
  cmake,
  crunch,
  cryptopp,
  curl,
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
    "-DGEOTIFF_LIBRARY_RELEASE=${lib.getLib libgeotiff}/lib/libgeotiff${stdenv.hostPlatform.extensions.sharedLibrary}"
    "-DBUILD_DOCS=OFF"
    "-DBUILD_PYTHON_BINDINGS=OFF"
    "-DBUILD_JAVA_BINDINGS=OFF"
    "-DGDAL_BUILD_OPTIONAL_DRIVERS=OFF"
    "-DGDAL_USE_JPEG=OFF"
    "-DGDAL_USE_GIF=OFF"
    "-DGDAL_USE_SPATIALITE=OFF"
    "-DGDAL_ENABLE_DRIVER_AAIGRID=ON"
    "-DOGR_ENABLE_DRIVER_CSV=ON"
  ]
  ++ lib.optionals (!stdenv.hostPlatform.isDarwin) [
    "-DCMAKE_SKIP_BUILD_RPATH=ON" # without, libgdal.so can't find libmariadb.so
  ]
  ++ lib.optionals stdenv.hostPlatform.isDarwin [
    "-DCMAKE_BUILD_WITH_INSTALL_NAME_DIR=ON"
  ]
  ++ lib.optionals (!useTiledb) [
    "-DGDAL_USE_TILEDB=OFF"
  ]
  ++ (if static then [ "-DBUILD_SHARED_LIBS=OFF" ] else [ "-DBUILD_SHARED_LIBS=ON" ]);

  buildInputs =
    let
      tileDbDeps = lib.optionals useTiledb [ tiledb ];
      postgresDeps = lib.optionals usePostgres [ libpq ];
      arrowDeps = lib.optionals useArrow [ arrow-cpp ];
      hdfDeps = lib.optionals useHDF [
        hdf4
        hdf5-cpp
      ];
      netCdfDeps = lib.optionals useNetCDF [ netcdf ];
      armadilloDeps = lib.optionals useArmadillo [ armadillo ];

      darwinDeps = lib.optionals stdenv.hostPlatform.isDarwin [ libiconv ];
      nonDarwinDeps = lib.optionals (!stdenv.hostPlatform.isDarwin) [
        arrowDeps
      ];
    in
    [
      c-blosc
      crunch
      curl
      cryptopp
      libdeflate
      expat
      libgeotiff
      geos
      json_c
      lerc
      xz
      libxml2
      lz4
      openssl
      pcre2
      libpng
      proj
      qhull
      sqlite
      libtiff
      zlib
      zstd
    ]
    ++ tileDbDeps
    ++ postgresDeps
    ++ arrowDeps
    ++ hdfDeps
    ++ netCdfDeps
    ++ armadilloDeps
    ++ darwinDeps
    ++ nonDarwinDeps;

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
