{
  lib,
  stdenv,
  qtbase,
  qtbaseNative ? null,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  # Minimal dependency overrides
  pcre2,
  zlib,
  icu,
  sqlite,
  openssl,
}:

qtbase.overrideAttrs (old: {
  pname = mkPackageName "qtbase-minimal" static stdenv;

  # Only the non-GUI dependencies needed for Core, Sql, Xml, Network.
  propagatedBuildInputs = [
    openssl
    sqlite
    zlib
    icu
    pcre2
  ];

  buildInputs = [ ];

  # Drop wayland-scanner and other propagated native deps we don't need.
  propagatedNativeBuildInputs = [ ];

  cmakeFlags = [
    "--log-level=STATUS"
    "-DQT_EMBED_TOOLCHAIN_COMPILER=OFF"
    "-DINSTALL_PLUGINSDIR=lib/qt-6/plugins"
    "-DINSTALL_QMLDIR=lib/qt-6/qml"

    # Use the system libraries we provide
    "-DQT_FEATURE_system_sqlite=ON"
    "-DQT_FEATURE_system_pcre2=ON"
    "-DQT_FEATURE_system_zlib=ON"
    "-DQT_FEATURE_openssl_linked=ON"
    "-DQT_FEATURE_icu=ON"

    # Use bundled copies for the rest (double-conversion, libb2, md4c, …)
    "-DQT_FEATURE_system_doubleconversion=OFF"
    "-DQT_FEATURE_system_libb2=OFF"

    # ── Disable the entire GUI / widgets stack ──────────────────────────
    "-DQT_FEATURE_gui=OFF"
    "-DQT_FEATURE_widgets=OFF"
    "-DQT_FEATURE_opengl=OFF"
    "-DQT_FEATURE_opengles2=OFF"
    "-DQT_FEATURE_vulkan=OFF"

    # ── Disable platform integrations ───────────────────────────────────
    "-DQT_FEATURE_dbus=OFF"
    "-DQT_FEATURE_xcb=OFF"
    "-DQT_FEATURE_linuxfb=OFF"
    "-DQT_FEATURE_eglfs=OFF"
    "-DQT_FEATURE_evdev=OFF"
    "-DQT_FEATURE_libinput=OFF"
    "-DQT_FEATURE_mtdev=OFF"
    "-DQT_FEATURE_tslib=OFF"
    "-DQT_FEATURE_cups=OFF"
    "-DQT_FEATURE_glib=OFF"

    # ── Disable extras ──────────────────────────────────────────────────
    "-DQT_FEATURE_testlib=OFF"
    "-DQT_FEATURE_printsupport=OFF"
    "-DQT_BUILD_EXAMPLES=OFF"
    "-DQT_BUILD_TESTS=OFF"
    "-DQT_GENERATE_SBOM=OFF"

    # Prevent the host OS version from leaking into the output
    "-DCMAKE_SYSTEM_VERSION="

    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ]
  ++ lib.optionals (stdenv.hostPlatform != stdenv.buildPlatform && qtbaseNative != null) [
    "-DQT_HOST_PATH=${qtbaseNative}"
  ]
  ++ lib.optionals static [
    "-DQT_FEATURE_reduce_relocations=OFF"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
  ];

  # The stock nixpkgs postFixup tries to patchelf libQt6Gui.so and the
  # MySQL SQL driver — neither of which exist in this minimal build.
  # Keep only the generic cmake / mkspecs fixups and the setup-hook
  # substitution.
  postFixup = ''
    moveToOutput "mkspecs/modules" "$dev"
    fixQtModulePaths "$dev/mkspecs/modules"
    fixQtBuiltinPaths "$out" '*.pr?'

    substituteInPlace "''${!outputDev}/nix-support/setup-hook" \
      --replace-fail "@qtbaseOut@" $out
  '';

  meta = old.meta // {
    description = "Qt 6 base libraries – minimal headless build (Core, Sql, Xml, Network only)";
  };
})
