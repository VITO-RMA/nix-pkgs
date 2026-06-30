{
  lib,
  stdenv,
  json_c,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

let
  hostPlatform = stdenv.hostPlatform;
  isMsvc =
    (hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((hostPlatform.isWindows or false) && (hostPlatform.abi.name or "" == "msvc"));
in
(json_c.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;
    cmakeFlags =
      old.cmakeFlags or [ ]
      ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ]
      # The MSVC/clang toolchain promotes warnings (e.g. the unused
      # json_c_snprintf compat shim) to errors via -Werror; disable that.
      ++ lib.optional isMsvc (lib.cmakeBool "DISABLE_WERROR" true);
    # We target the MSVC ABI with the clang GNU driver, so CMake does not set
    # its `MSVC` variable and falls back to probing the POSIX `ssize_t` type,
    # which does not exist on this target. That leaves SIZEOF_SSIZE_T undefined
    # and json_object.c fails with "Unable to determine size of ssize_t".
    # Widen the guard to WIN32 so the Windows `SSIZE_T`/BaseTsd.h probe is used
    # instead (the ssize_t type itself is typedef'd for _MSC_VER in
    # json_object_private.h).
    postPatch =
      (old.postPatch or "")
      + lib.optionalString isMsvc ''
        substituteInPlace CMakeLists.txt \
          --replace $'if (MSVC)\nlist(APPEND CMAKE_EXTRA_INCLUDE_FILES BaseTsd.h)' \
                    $'if (WIN32)\nlist(APPEND CMAKE_EXTRA_INCLUDE_FILES BaseTsd.h)'
      '';
    meta = old.meta // {
      platforms = lib.platforms.all;
    };
  })
