{
  lib,
  stdenv,
  howard-hinnant-date,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(howard-hinnant-date.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    postPatch = (old.postPatch or "") + ''
      substituteInPlace CMakeLists.txt \
        --replace-fail \
          'if( WIN32 AND NOT CYGWIN)' \
          'if( WIN32 AND NOT MINGW)'
    '';

    cmakeFlags = [
      "-DBUILD_TZ_LIB=ON"
      "-DUSE_SYSTEM_TZ_DB=ON"
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    ];
  })
