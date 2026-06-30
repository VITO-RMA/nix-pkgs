{
  lib,
  stdenv,
  hdf4,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  libjpeg,
  zlib,
  fortranSupport ? false,
  netcdfSupport ? false,
}:

let
  isMsvc =
    (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));
in
(hdf4.override {
  netcdfSupport = netcdfSupport;
  fortranSupport = fortranSupport;
  szipSupport = false;
}).overrideAttrs
  (old: rec {
    pname = mkPackageName old.pname static stdenv;

    # This toolchain is clang driven by its GNU driver (not clang-cl), so CMake
    # leaves `MSVC` unset (it means "cl.exe-compatible CLI", not "MSVC ABI").
    # Like HDF5, HDF4's `ConfigureChecks.cmake` seeds `CMAKE_REQUIRED_FLAGS`
    # with MSVC `/D...` syntax on the `WIN32 AND NOT MINGW` path, which the GNU
    # driver treats as input file paths, breaking *every* configure-time
    # `try_compile` (so e.g. `sys/stat.h` is reported missing and `struct stat`
    # ends up undefined in hextelt.c). Rewrite to the `-D` form.
    postPatch =
      (old.postPatch or "")
      + lib.optionalString isMsvc ''
        substituteInPlace config/cmake/ConfigureChecks.cmake \
          --replace-fail \
            'set (CMAKE_REQUIRED_FLAGS "/DWIN32_LEAN_AND_MEAN=1 /DNOGDI=1")' \
            'set (CMAKE_REQUIRED_FLAGS "-DWIN32_LEAN_AND_MEAN=1 -DNOGDI=1")'
      '';

    buildInputs = [
      zlib
      libjpeg
    ];
    propagatedBuildInputs = buildInputs;
    doCheck = false;

    # nixpkgs' hdf4 sets BUILD_SHARED_LIBS in its own cmakeFlags; replace it
    # instead of adding a conflicting duplicate.
    cmakeFlags =
      let
        oldFlags = old.cmakeFlags or [ ];
        filteredOldFlags = builtins.filter (f: !(lib.hasPrefix "-DBUILD_SHARED_LIBS" f)) oldFlags;
      in
      filteredOldFlags ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];

    meta = old.meta // {
      platforms = lib.platforms.all;
    };
  })
