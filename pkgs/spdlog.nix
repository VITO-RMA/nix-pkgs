{
  lib,
  stdenv,
  spdlog,
  fmt,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(spdlog.override {
  inherit fmt;
  staticBuild = static;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    cmakeFlags = old.cmakeFlags or [ ] ++ [ (lib.cmakeBool "SPDLOG_BUILD_TESTS" false) ];
  })
