{
  lib,
  stdenv,
  libuv,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

libuv.overrideAttrs (old: {
  pname = mkPackageName old.pname static stdenv;
  doCheck = false;
  checkInputs = [ ];
  nativeCheckInputs = [ ];
  preCheck = "";

  nativeBuildInputs = [ cmake ];
  preConfigure = "";

  # libuv 1.52.1 made the public CPU model field const, but its Windows
  # UTF-16 conversion helper still needs a mutable output pointer.
  postPatch =
    (old.postPatch or "")
    + ''
      # Nix passes absolute install directories; prepending the prefix again
      # produces invalid library and include paths in both pkg-config files.
      substituteInPlace CMakeLists.txt \
        --replace-fail 'set(libdir ''${CMAKE_INSTALL_PREFIX}/''${CMAKE_INSTALL_LIBDIR})' \
          'set(libdir ''${CMAKE_INSTALL_FULL_LIBDIR})' \
        --replace-fail 'set(includedir ''${CMAKE_INSTALL_PREFIX}/''${CMAKE_INSTALL_INCLUDEDIR})' \
          'set(includedir ''${CMAKE_INSTALL_FULL_INCLUDEDIR})'
    ''
    + lib.optionalString stdenv.hostPlatform.isMinGW ''
      substituteInPlace src/win/util.c \
        --replace-fail '    WCHAR cpu_brand[256];' '    char* model = NULL;
      WCHAR cpu_brand[256];' \
        --replace-fail '&(cpu_info->model));' '&model);
      cpu_info->model = model;' \
        --replace-fail 'uv__free(cpu_infos[i].model);' 'uv__free((void*) cpu_infos[i].model);'
    '';
  separateDebugInfo = !static;

  cmakeFlags = [
    (lib.cmakeBool "LIBUV_BUILD_SHARED" (!static))
    (lib.cmakeBool "LIBUV_BUILD_TESTS" false)
    (lib.cmakeBool "LIBUV_BUILD_BENCH" false)
  ];
})
