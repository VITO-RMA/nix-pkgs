{
  lib,
  stdenv,
  spdlog,
  fmt,
  static ? stdenv.hostPlatform.isStatic,
}:

(spdlog.override {
  staticBuild = static;
}).overrideAttrs
  (old: {
    doCheck = false;

    buildInputs = [ fmt ];

    cmakeFlags = old.cmakeFlags or [ ] ++ [ (lib.cmakeBool "SPDLOG_BUILD_TESTS" false) ];
  })
