{
  lib,
  stdenv,
  xz,
  cmake,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  ...
}:

let
  hostPlatform = stdenv.hostPlatform;
  isMsvc =
    (hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((hostPlatform.isWindows or false) && (hostPlatform.abi.name or "" == "msvc"));
in
if !isMsvc then
  (xz.override {
    enableStatic = static;
  }).overrideAttrs
    (old: {
      pname = mkPackageName old.pname static stdenv;
      doCheck = false;
    })
else
  # The Autotools build hardcodes <pthread.h> for threading, which the MSVC
  # target lacks. Upstream ships a CMake build (the one vcpkg uses) that builds
  # liblzma with native Win32 threads instead, so use that for MSVC. We only
  # need the library, so the command line tools are disabled like vcpkg's
  # default (no "tools" feature).
  stdenv.mkDerivation (finalAttrs: {
    pname = mkPackageName "xz" static stdenv;
    inherit (xz) version src;
    # Inherit upstream metadata, but drop outputsToInstall: it was computed for
    # nixpkgs xz's outputs (bin/man/...) which this CMake build doesn't produce.
    meta = builtins.removeAttrs xz.meta [ "outputsToInstall" ];

    outputs = [
      "out"
      "dev"
    ];

    nativeBuildInputs = [ cmake ];

    cmakeFlags = [
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
      (lib.cmakeBool "BUILD_TESTING" false)
      (lib.cmakeBool "XZ_NLS" false)
      (lib.cmakeFeature "XZ_SANDBOX" "no")
      (lib.cmakeBool "XZ_TOOL_XZ" false)
      (lib.cmakeBool "XZ_TOOL_XZDEC" false)
      (lib.cmakeBool "XZ_TOOL_LZMADEC" false)
      (lib.cmakeBool "XZ_TOOL_LZMAINFO" false)
      (lib.cmakeBool "XZ_TOOL_SYMLINKS" false)
      (lib.cmakeBool "XZ_TOOL_SYMLINKS_LZMA" false)
    ];

    doCheck = false;
  })
