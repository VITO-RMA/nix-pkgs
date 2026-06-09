{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  libpq,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "libpqxx" static stdenv;
  version = "7.10.1";

  src = fetchFromGitHub {
    owner = "jtv";
    repo = "libpqxx";
    rev = version;
    hash = "sha256-BVmIyJA5gDibwtmDvw7b300D0KdWv7c3Ytye6fiLAXU=";
  };

  outputs = [
    "out"
    "dev"
  ];

  nativeBuildInputs = [
    cmake
  ];

  buildInputs = [
    libpq
  ];

  propagatedBuildInputs = [
    libpq
  ];

  # Fix .pc file generation: use absolute paths instead of ${prefix}-relative ones.
  # When Nix sets CMAKE_INSTALL_*DIR to absolute store paths, the
  # "${prefix}/${CMAKE_INSTALL_LIBDIR}" pattern produces broken double-slash paths.
  postPatch = ''
    substituteInPlace src/CMakeLists.txt \
      --replace-fail \
        'set(libdir "''\\''${prefix}/''${CMAKE_INSTALL_LIBDIR}")' \
        'set(libdir "''${CMAKE_INSTALL_FULL_LIBDIR}")' \
      --replace-fail \
        'set(includedir "''\\''${prefix}/''${CMAKE_INSTALL_INCLUDEDIR}")' \
        'set(includedir "''${CMAKE_INSTALL_FULL_INCLUDEDIR}")'
  '';

  cmakeFlags = [
    "-DSKIP_BUILD_TEST=ON"
    "-DBUILD_DOC=OFF"
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ];

  strictDeps = true;

  meta = with lib; {
    changelog = "https://github.com/jtv/libpqxx/releases/tag/${version}";
    description = "C++ library to access PostgreSQL databases";
    downloadPage = "https://github.com/jtv/libpqxx";
    homepage = "https://pqxx.org/development/libpqxx/";
    license = licenses.bsd3;
    platforms = platforms.all;
  };
}
