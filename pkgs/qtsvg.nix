{
  lib,
  stdenv,
  qtsvg,
  qtbase,
  qtbaseNative ? null,
  zlib,
  libxkbcommon ? null,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(qtsvg.override {
  inherit qtbase zlib;
}).overrideAttrs
  (old: {
    pname = mkPackageName "qtsvg" static stdenv;

    # QtSvg links Qt's private GUI targets while building. Their CMake package
    # requires XKB, which qtbase itself does not propagate to module builds.
    propagatedBuildInputs =
      (old.propagatedBuildInputs or [ ]) ++ lib.optionals (libxkbcommon != null) [ libxkbcommon ];

    cmakeFlags =
      (old.cmakeFlags or [ ])
      ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ]
      ++ lib.optionals (stdenv.hostPlatform != stdenv.buildPlatform && qtbaseNative != null) [
        "-DQT_HOST_PATH=${qtbaseNative}"
      ];
  })
