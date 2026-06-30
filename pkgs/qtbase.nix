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
  withWayland ? gui && stdenv.hostPlatform.isLinux,
  # Wayland QPA stack. Linked dynamically on Linux GUI builds; null elsewhere.
  wayland ? null,
  wayland-scanner ? null,
  libxkbcommon ? null,
  libdrm ? null,
  libgbm ? null,
  # Desktop OpenGL implementation.
  #  • Linux : the NixOS GL stack (libglvnd). The vendor driver is loaded at
  #            runtime from /run/opengl-driver/lib, so we only link the
  #            dispatch library here.
  #  • MinGW : `null` — OpenGL (opengl32) is shipped with the cross toolchain
  #            and is picked up automatically, so no nix package is required.
  libGL ? null,
  # CUPS — required by PrintSupport on all platforms. The Apple SDK strips
  # its CUPS headers/stubs in favour of the nixpkgs package, so we need
  # the nixpkgs cups everywhere.
  cups ? null,
}:

let
  inherit (stdenv.hostPlatform)
    isMinGW
    isWindows
    isLinux
    isDarwin
    ;
  isMsvc =
    (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));

  # MSVC: forward CMAKE_MSVC_RUNTIME_LIBRARY to the architecture extraction
  # sub-project so it doesn't default to the debug DLL CRT (msvcrtd) that
  # is not available in the xwin SDK.
  msvcArchTestPatch = ../patches/qtbase-arch-test-msvc-runtime.patch;
  msvcLibcxxInt128Patch = ../patches/qtbase-msvc-libcxx-no-msvc-int128.patch;
  msvcLibcxxCheckedIteratorPatch = ../patches/qtbase-msvc-libcxx-no-stdext-checked-iterator.patch;
  icuSupport = !isMsvc;
  # Desktop OpenGL is available on Linux (libglvnd), Windows (opengl32 from the
  # SDK/toolchain) and Darwin (the system OpenGL framework, resolved from the SDK).
  # On Darwin it must stay enabled: a GUI build with every OpenGL backend off
  # but without INPUT_opengl=no trips Qt's "OpenGL functionality tests failed"
  # fatal error in src/gui/configure.cmake. On Windows, the platform plugin still
  # builds OpenGL-dependent code paths, so keep desktop OpenGL enabled there too.
  openglSupport = gui && (isLinux || isWindows || isDarwin);
  qtFeature = name: enabled: "-DQT_FEATURE_${name}=${if enabled then "ON" else "OFF"}";
  tlsFlags =
    if isWindows then
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

  # Re-override the upstream qtbase so its wayland support tracks our `gui`
  # flag: build the wayland QPA plugin only for a GUI build on Linux.
  qtbase' = qtbase.override { inherit withWayland; };
in
qtbase'.overrideAttrs (old: {
  pname = mkPackageName (if gui then "qtbase" else "qtbase-headless") static stdenv;

  # MSVC: fix architecture extraction test runtime selection
  patches =
    (old.patches or [ ])
    ++ lib.optionals isMsvc [
      msvcArchTestPatch
      msvcLibcxxInt128Patch
      msvcLibcxxCheckedIteratorPatch
    ];

  # Non-GUI dependencies needed for Core, Sql, Xml, Network, plus the GL
  # dispatch library on platforms where it comes from nixpkgs (Linux).
  # OpenSSL is only pulled in where it's the TLS backend; MinGW uses the
  # OS-provided Schannel and Darwin uses SecureTransport instead.
  propagatedBuildInputs = [
    sqlite
    zlib
    zstd
    pcre2
  ]
  ++ lib.optionals icuSupport [ icu ]
  ++ lib.optionals (!isWindows && !isDarwin) [ openssl ]
  ++ lib.optionals gui (
    lib.filter (x: x != null) [
      libpng
      libjpeg
    ]
  )
  ++ lib.optionals (openglSupport && libGL != null) [ libGL ]
  ++ lib.optional (cups != null && lib.meta.availableOn stdenv.hostPlatform cups) cups;

  # Wayland QPA plugin deps. Dynamically linked on Linux GUI builds.
  buildInputs = lib.optionals withWayland (
    lib.filter (x: x != null) [
      wayland
      libxkbcommon
      libdrm
      libgbm
    ]
  );

  nativeBuildInputs =
    (old.nativeBuildInputs or [ ])
    ++ lib.optionals withWayland (lib.filter (x: x != null) [ wayland-scanner ]);

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
    (qtFeature "icu" icuSupport)

    # Use bundled copies for the rest (double-conversion, libb2, md4c, …)
    "-DQT_FEATURE_system_doubleconversion=OFF"
    "-DQT_FEATURE_system_libb2=OFF"

    # ── GUI / Widgets / OpenGL stack ────────────────────────────────────
    (qtFeature "gui" gui)
    (qtFeature "widgets" gui)
    # Desktop OpenGL (links libGL on Linux / opengl32 on MinGW / the system
    # OpenGL framework on Darwin). We don't build the GLES/EGL or Vulkan
    # backends in this variant.
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
    # Disable windowing backends we don't need. Wayland is kept when
    # gui + Linux so that the wayland QPA plugin is built.
    "-DQT_FEATURE_dbus=OFF"
    "-DQT_FEATURE_xcb=OFF"
    "-DQT_FEATURE_linuxfb=OFF"
    "-DQT_FEATURE_eglfs=OFF"
    "-DQT_FEATURE_evdev=OFF"
    "-DQT_FEATURE_libinput=OFF"
    "-DQT_FEATURE_mtdev=OFF"
    "-DQT_FEATURE_tslib=OFF"
    (qtFeature "cups" gui)
    "-DQT_FEATURE_glib=OFF"
    (qtFeature "wayland" withWayland)

  ]
  ++ [
    # ── Disable extras ──────────────────────────────────────────────────
    "-DQT_FEATURE_testlib=ON"
    (qtFeature "printsupport" gui)
    "-DQT_FEATURE_androiddeployqt=OFF"
    "-DQT_FEATURE_wasmdeployqt=OFF"
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
  ]
  ++ lib.optionals (static && isDarwin) [
    # Static frameworks are atypical on Darwin and Qt's cmake configs
    # reference a flat include/ directory that doesn't get created
    # alongside framework bundles.  Disable frameworks so Qt installs
    # as plain static libs + include/ (same layout as Linux).
    (qtFeature "framework" false)
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
      "Qt 6 base libraries – "
      + (
        if gui then
          "GUI build (Core, Sql, Xml, Network, Gui, Widgets"
        else
          "headless build (Core, Sql, Xml, Network"
      )
      + lib.optionalString openglSupport " + desktop OpenGL"
      + ")";
  };
})
