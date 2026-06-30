{
  lib,
  stdenv,
  libjpeg,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  fetchFromGitHub,
}:

let
  hostPlatform = stdenv.hostPlatform;
  isMsvc =
    (hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((hostPlatform.isWindows or false) && (hostPlatform.abi.name or "" == "msvc"));
in
(libjpeg.override {
  enableShared = !static;
  enableStatic = static;
}).overrideAttrs
  (old: rec {
    pname = mkPackageName old.pname static stdenv;
    version = "3.1.4.1";
    src = fetchFromGitHub {
      owner = "libjpeg-turbo";
      repo = "libjpeg-turbo";
      rev = version;
      hash = "sha256-jBajigX4/j4jG11prTPeGkTVRrRzheFL/LxgnPufzb4=";
    };

    patches = [ ./patches/libjpeg-mingw-boolean.patch ];

    # libjpeg-turbo's CMake install only lays down man pages on Unix hosts, so
    # the declared `man` output is never created when cross-building to Windows.
    # Create it so Nix accepts the multi-output derivation.
    postInstall =
      (old.postInstall or "")
      + lib.optionalString isMsvc ''
        mkdir -p "$man"
      '';
  })
