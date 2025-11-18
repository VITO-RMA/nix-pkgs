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

    buildInputs = old.buildInputs ++ lib.optionals static [ fmt ];
  })
