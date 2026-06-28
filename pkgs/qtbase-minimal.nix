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
  zstd,
  icu,
  sqlite,
  openssl,
  libpng ? null,
  libjpeg ? null,
  gui ? !stdenv.hostPlatform.isMusl,
  # Desktop OpenGL implementation.
  #  • Linux : the NixOS GL stack (libglvnd). The vendor driver is loaded at
  #            runtime from /run/opengl-driver/lib, so we only link the
  #            dispatch library here.
  #  • MinGW : `null` — OpenGL (opengl32) is shipped with the cross toolchain
  #            and is picked up automatically, so no nix package is required.
  libGL ? null,
}:

let
  inherit (stdenv.hostPlatform) isMinGW isLinux isDarwin;
  openglSupport = gui && (isLinux || isMinGW);
  qtFeature = name: enabled: "-DQT_FEATURE_${name}=${if enabled then "ON" else "OFF"}";
  tlsFlags =
    if isMinGW then
      [
        (qtFeature "schannel" true)
        (qtFeature "openssl" false)
      ]
    else if isDarwin then
      [
        (qtFeature "securetransport" true)
        (qtFeature "openssl" false)
      ]
    else
      [ (qtFeature "openssl_linked" true) ];
in
qtbase.overrideAttrs (old: {
  pname = mkPackageName "qtbase-minimal" static stdenv;

  # Non-GUI dependencies needed for Core, Sql, Xml, Network, plus the GL
  # dispatch library on platforms where it comes from nixpkgs (Linux).
  # OpenSSL is only pulled in where it's the TLS backend; MinGW uses the
  # OS-provided Schannel and Darwin uses SecureTransport instead.
  propagatedBuildInputs = [
    sqlite
    zlib
    zstd
    icu
    pcre2
  ]
  ++ lib.optionals (!isMinGW && !isDarwin) [ openssl ]
  ++ lib.optionals gui (
    lib.filter (x: x != null) [
      libpng
      libjpeg
    ]
  )
  ++ lib.optionals (openglSupport && libGL != null) [ libGL ];

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
    "-DQT_FEATURE_system_zstd=ON"
    "-DQT_FEATURE_icu=ON"

    # Use bundled copies for the rest (double-conversion, libb2, md4c, …)
    "-DQT_FEATURE_system_doubleconversion=OFF"
    "-DQT_FEATURE_system_libb2=OFF"

    # ── GUI / Widgets / OpenGL stack ────────────────────────────────────
    (qtFeature "gui" gui)
    (qtFeature "widgets" gui)
    # Desktop OpenGL (links libGL on Linux / opengl32 on MinGW). We don't
    # build the GLES/EGL or Vulkan backends in this minimal variant.
    (qtFeature "opengl" openglSupport)
    (qtFeature "opengl_desktop" openglSupport)
    "-DQT_FEATURE_opengles2=OFF"
    "-DQT_FEATURE_vulkan=OFF"

    # Keep the font stack self-contained (bundled freetype, harfbuzz) so
    # enabling GUI doesn't pull in a windowing-system worth of dependencies,
    # but use the system libpng / libjpeg we already build.
    "-DQT_FEATURE_system_freetype=OFF"
    "-DQT_FEATURE_system_harfbuzz=OFF"
    (qtFeature "system_libpng" (gui && libpng != null))
    (qtFeature "system_libjpeg" (gui && libjpeg != null))
    "-DQT_FEATURE_fontconfig=OFF"

    # ── Disable platform integrations ───────────────────────────────────
    # GUI is built with only the always-available "minimal"/"offscreen"
    # platform plugins; no real windowing system is linked.
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
  ++ tlsFlags
  ++ lib.optionals isDarwin [
    # Match the upstream nixpkgs qtbase Darwin flags. Overriding cmakeFlags
    # wholesale drops them, and without these the configure step tries to run
    # `xcrun xcodebuild -version` to determine the Xcode version — which fails
    # in the Nix sandbox ("Can't determine Xcode version. Is Xcode installed?").
    "-DQT_FEATURE_rpath=OFF"
    "-DQT_NO_XCODE_MIN_VERSION_CHECK=ON"
    # Only used by the (now disabled) min-version check. Setting it prevents
    # cmake from shelling out to xcodebuild to query the version.
    "-DQT_INTERNAL_XCODE_VERSION=0.1"
  ]
  ++ lib.optionals (stdenv.hostPlatform != stdenv.buildPlatform && qtbaseNative != null) [
    "-DQT_HOST_PATH=${qtbaseNative}"
  ]
  ++ lib.optionals static [
    "-DQT_FEATURE_reduce_relocations=OFF"
    "-DCMAKE_POSITION_INDEPENDENT_CODE=ON"
  ];

  # The stock nixpkgs postFixup tries to patchelf libQt6Gui.so and the
  # MySQL SQL driver — the latter never exists in this build, and for our
  # static builds there is no libQt6Gui.so to patch either. Keep only the
  # generic cmake / mkspecs fixups and the setup-hook substitution.
  postFixup = ''
    moveToOutput "mkspecs/modules" "$dev"
    fixQtModulePaths "$dev/mkspecs/modules"
    fixQtBuiltinPaths "$out" '*.pr?'

    substituteInPlace "''${!outputDev}/nix-support/setup-hook" \
      --replace-fail "@qtbaseOut@" $out
  '';

  meta = old.meta // {
    description =
      "Qt 6 base libraries – minimal build (Core, Sql, Xml, Network"
      + lib.optionalString gui ", Gui, Widgets"
      + lib.optionalString openglSupport " + desktop OpenGL"
      + ")";
  };
})
