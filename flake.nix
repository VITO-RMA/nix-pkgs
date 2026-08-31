{
  description = "Reusable static overrides for various libraries";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-26.05";

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      mkPackageName =
        pkg: static: stdenv:
        let
          clib =
            if stdenv.hostPlatform.config or "" == "x86_64-w64-mingw32" then
              ""
            else if stdenv.hostPlatform.isStatic then
              "-musl"
            else if stdenv.hostPlatform.isDarwin then
              "-darwin"
            else
              "-glibc";
          suffix = if static && !(stdenv.hostPlatform.isStatic) then "-static" else "";
        in
        "${pkg}${suffix}${clib}";

      mkZigCrossGlibcStdenv =
        {
          buildPackages,
          baseStdenv,
          glibcVersion ? "2.28",
        }:
        let
          targetPlatform = baseStdenv.targetPlatform;
          target = "${targetPlatform.system}-${targetPlatform.parsed.abi.name}.${glibcVersion}";
          portablePlatform = targetPlatform // {
            config = "${targetPlatform.parsed.cpu.name}-any-linux-${targetPlatform.parsed.abi.name}";
          };
          zig = buildPackages.zig_0_16;
          # Re-wrap the target LLVM tools without nixpkgs glibc. This keeps ar,
          # ranlib, and the linker available without injecting a Nix-store
          # dynamic loader into target executables.
          targetBintools = buildPackages.wrapBintoolsWith {
            bintools = buildPackages.gcc.bintools.bintools;
            libc = null;
          };
          zigCC = buildPackages.wrapCCWith {
            name = "zig-glibc-${glibcVersion}";
            cc = zig.cc-unwrapped;
            bintools = targetBintools;
            libc = null;
            extraPackages = [ ];
            # Zig 0.16 accepts linker dependency files but currently crashes
            # while processing them for some CMake targets.
            extraBuildCommands = ''
              # Zig sets libc++ hardening to NONE before forwarding compiler
              # arguments. Undefine it before Nix selects its hardened mode to
              # avoid a macro-redefinition warning in every C++ translation unit.
              substituteInPlace "$out/nix-support/add-hardening.sh" \
                --replace-fail \
                  "hardeningCFlagsBefore+=('-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST')" \
                  "hardeningCFlagsBefore+=('-U_LIBCPP_HARDENING_MODE' '-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_FAST')" \
                --replace-fail \
                  "hardeningCFlagsBefore+=('-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_EXTENSIVE')" \
                  "hardeningCFlagsBefore+=('-U_LIBCPP_HARDENING_MODE' '-D_LIBCPP_HARDENING_MODE=_LIBCPP_HARDENING_MODE_EXTENSIVE')"

              cat > $out/nix-support/zig-meson-cross-file.conf <<'EOF'
              [binaries]
              ar = '${targetPlatform.config}-ar'
              ranlib = '${targetPlatform.config}-ranlib'
              strip = '${targetPlatform.config}-strip'
              EOF

              cat > $out/nix-support/zig-meson-native-file.conf <<'EOF'
              [binaries]
              c = '${buildPackages.stdenv.cc}/bin/cc'
              cpp = '${buildPackages.stdenv.cc}/bin/c++'
              ar = '${buildPackages.stdenv.cc.bintools}/bin/ar'
              ranlib = '${buildPackages.stdenv.cc.bintools}/bin/ranlib'
              strip = '${buildPackages.stdenv.cc.bintools}/bin/strip'
              EOF

              cat <<'EOF' >> $out/nix-support/setup-hook
              appendToVar cmakeFlags "-DCMAKE_LINK_DEPENDS_USE_LINKER=FALSE"
              appendToVar mesonFlags "--cross-file=$NIX_CC/nix-support/zig-meson-cross-file.conf"
              appendToVar mesonFlags "--native-file=$NIX_CC/nix-support/zig-meson-native-file.conf"
              EOF
            '';
            nixSupport.cc-cflags = [
              "-target"
              target
            ];
          };
        in
        assert targetPlatform.isLinux && targetPlatform.isGnu;
        buildPackages.overrideCC (baseStdenv.override {
          # The CPU and kernel match the build machine, but target binaries
          # use a distro loader that is intentionally absent in the sandbox.
          buildPlatform = baseStdenv.buildPlatform // {
            canExecute = _: false;
          };
          hostPlatform = portablePlatform;
          targetPlatform = portablePlatform;
        }) zigCC;

      mingwOverlay =
        final: prev:
        let
          baseStdenv = prev.stdenv or null;
        in
        # During early bootstrap `prev.stdenv` can be null or incomplete.
        if baseStdenv == null then
          { }
        else
          let
            host = baseStdenv.hostPlatform;
            isMingw = (host.config or "" == "x86_64-w64-mingw32") || (host.isWindows or false);
          in
          if !isMingw then
            { }
          else
            let
              buildPkgs = prev.buildPackages;
              staticLinkFlagsHook = ''
                cat <<EOF >> $out/nix-support/setup-hook
                export NIX_CFLAGS_LINK="$NIX_CFLAGS_LINK -static-libgcc -static-libstdc++"
                EOF
              '';
              gccWin32 = buildPkgs.wrapCCWith {
                cc = buildPkgs.gcc-unwrapped.override {
                  # Uss win32 threads instead of posix mcfgthread:
                  # threadsCross = {
                  #   model = "win32";
                  #   package = null;
                  # };
                };
                extraBuildCommands = staticLinkFlagsHook;
              };

              stdenvWinBase = prev.overrideCC baseStdenv gccWin32;
              stdenvWin = stdenvWinBase // {
                hostPlatform = stdenvWinBase.hostPlatform // {
                  isStatic = true;
                };
              };
            in
            {
              # make this the stdenv for MinGW targets
              stdenv = stdenvWin;
            };

      # mkOverlay is a function that creates a Nix overlay for overriding or adding packages.
      # we prepend the packages with pkg to avoid rebuilding the world
      # otherwise all the packages in the system that depend on one of these
      # packages would need to be rebuilt to link against the static version
      #
      # we prepend the packages with pkg-mod- to avoid rebuilding the world
      # otherwise all the packages in the system that depend on one of these
      # packages would need to be rebuilt to link against the static version
      mkOverlay =
        {
          static ? false,
        }:
        (
          final: prev:
          let
            stdenv = prev.stdenv;
          in
          {
            pkg-mod-benchmark = final.callPackage ./pkgs/benchmark.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-boost = final.callPackage ./pkgs/boost.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
              zstd = final.pkg-mod-zstd;
              xz = final.pkg-mod-xz;
            };

            pkg-mod-brotli = final.callPackage ./pkgs/brotli.nix {
              inherit static stdenv mkPackageName;
            };
            pkg-mod-cryptopp = final.callPackage ./pkgs/cryptopp.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-curl = final.callPackage ./pkgs/curl.nix {
              inherit static stdenv mkPackageName;
              brotli = final.pkg-mod-brotli;
              openssl = final.pkg-mod-openssl;
              zlib = final.pkg-mod-zlib-compat;
              zstd = final.pkg-mod-zstd;
            };

            pkg-mod-debug_assert = final.callPackage ./pkgs/debug_assert.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-doctest = final.callPackage ./pkgs/doctest.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-eigen = final.callPackage ./pkgs/eigen.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-expat = final.callPackage ./pkgs/expat.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-fmt = final.callPackage ./pkgs/fmt.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-freexl = final.callPackage ./pkgs/freexl.nix {
              inherit static stdenv mkPackageName;
              expat = final.pkg-mod-expat;
              minizip = final.pkg-mod-minizip;
              zlib = final.pkg-mod-zlib-compat;
              libiconv =
                if (stdenv.hostPlatform.isWindows || stdenv.hostPlatform.isDarwin) then
                  final.pkg-mod-libiconv
                else
                  final.libiconv;
            };

            pkg-mod-gdal = final.callPackage ./pkgs/gdal.nix {
              inherit static stdenv mkPackageName;
              useMinimalFeatures = false;
              buildMinimalTools = true; # All tools are massive in size when static linking
              useArmadillo = false; # currently not needed in our builds
              useArrow = false; # currently not added because of additional dependency count
              useCBlosc = false; # currently not needed, required when zarr support is needed
              curl = final.pkg-mod-curl;
              qhull = final.pkg-mod-qhull;
              cryptopp = final.pkg-mod-cryptopp;
              c-blosc = final.c-blosc; # not overridden here yet
              expat = final.pkg-mod-expat;
              freexl = final.pkg-mod-freexl;
              geos = final.pkg-mod-geos;
              hdf4 = final.pkg-mod-hdf4;
              hdf5-cpp = final.pkg-mod-hdf5;
              json_c = final.pkg-mod-json_c;
              lerc = final.pkg-mod-lerc;
              libdeflate = final.pkg-mod-libdeflate;
              libgeotiff = final.pkg-mod-libgeotiff;
              libiconv =
                if (stdenv.hostPlatform.isWindows || stdenv.hostPlatform.isDarwin) then
                  final.pkg-mod-libiconv
                else
                  final.libiconv;
              libpng = final.pkg-mod-libpng;
              libpq = final.pkg-mod-libpq;
              libtiff = final.pkg-mod-libtiff;
              libxml2 = final.pkg-mod-libxml2;
              netcdf = final.pkg-mod-netcdf;
              lz4 = final.pkg-mod-lz4;
              openssl = final.pkg-mod-openssl;
              pcre2 = final.pkg-mod-pcre2;
              proj = final.pkg-mod-proj;
              sqlite = final.pkg-mod-sqlite;
              zlib = final.pkg-mod-zlib-compat;
              xz = final.pkg-mod-xz;
              zstd = final.pkg-mod-zstd;
            };

            pkg-mod-gdal-minimal = final.callPackage ./pkgs/gdal.nix {
              inherit static stdenv mkPackageName;
              useMinimalFeatures = true;
              curl = final.pkg-mod-curl;
              qhull = final.pkg-mod-qhull;
              cryptopp = final.pkg-mod-cryptopp;
              c-blosc = final.c-blosc; # not overridden here yet
              expat = final.pkg-mod-expat;
              freexl = final.pkg-mod-freexl;
              geos = final.pkg-mod-geos;
              hdf4 = final.pkg-mod-hdf4;
              hdf5-cpp = final.pkg-mod-hdf5;
              json_c = final.pkg-mod-json_c;
              lerc = final.pkg-mod-lerc;
              libdeflate = final.pkg-mod-libdeflate;
              libgeotiff = final.pkg-mod-libgeotiff;
              libiconv =
                if (stdenv.hostPlatform.isWindows || stdenv.hostPlatform.isDarwin) then
                  final.pkg-mod-libiconv
                else
                  final.libiconv;
              libpng = final.pkg-mod-libpng;
              libpq = final.pkg-mod-libpq;
              libtiff = final.pkg-mod-libtiff;
              libxml2 = final.pkg-mod-libxml2;
              netcdf = final.pkg-mod-netcdf;
              lz4 = final.pkg-mod-lz4;
              openssl = final.pkg-mod-openssl;
              pcre2 = final.pkg-mod-pcre2;
              proj = final.pkg-mod-proj;
              sqlite = final.pkg-mod-sqlite;
              zlib = final.pkg-mod-zlib-compat;
              xz = final.pkg-mod-xz;
              zstd = final.pkg-mod-zstd;
            };

            pkg-mod-geos = final.callPackage ./pkgs/geos.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-gtest = final.callPackage ./pkgs/gtest.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-hdf4 = final.callPackage ./pkgs/hdf4.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
              libjpeg = final.pkg-mod-libjpeg;
            };

            pkg-mod-hdf5 = final.callPackage ./pkgs/hdf5.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
              fortran = final.fortran;
              szip = final.szip;
              mpi = final.mpi;
            };

            pkg-mod-howard-hinnant-date = final.callPackage ./pkgs/howard-hinnant-date.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-hwloc = final.callPackage ./pkgs/hwloc.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-icu = final.callPackage ./pkgs/icu.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-indicators = final.callPackage ./pkgs/indicators.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-json_c = final.callPackage ./pkgs/json_c.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-libdeflate = final.callPackage ./pkgs/libdeflate.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
            };

            pkg-mod-libiconv = final.callPackage ./pkgs/libiconv.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-libgeotiff = final.callPackage ./pkgs/libgeotiff.nix {
              inherit static stdenv mkPackageName;
              libtiff = final.pkg-mod-libtiff;
              proj = final.pkg-mod-proj;
              zlib = final.pkg-mod-zlib-compat;
            };

            pkg-mod-libjpeg = final.callPackage ./pkgs/libjpeg.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-libpng = final.callPackage ./pkgs/libpng.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
            };

            pkg-mod-libpq = final.callPackage ./pkgs/libpq.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
              openssl = final.pkg-mod-openssl;
            };

            pkg-mod-libpqxx = final.callPackage ./pkgs/libpqxx.nix {
              inherit static stdenv mkPackageName;
              libpq = final.pkg-mod-libpq;
            };

            pkg-mod-libtiff = final.callPackage ./pkgs/libtiff.nix {
              inherit static stdenv mkPackageName;
              lerc = final.pkg-mod-lerc;
              libdeflate = final.pkg-mod-libdeflate;
              zlib = final.pkg-mod-zlib-compat;
              xz = final.pkg-mod-xz;
              zstd = final.pkg-mod-zstd;
            };

            pkg-mod-libxlsxwriter = final.callPackage ./pkgs/libxlsxwriter.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
              minizip = final.pkg-mod-minizip;
            };

            pkg-mod-libxml2 = final.callPackage ./pkgs/libxml2.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
              libiconv =
                if (stdenv.hostPlatform.isWindows || stdenv.hostPlatform.isDarwin) then
                  final.pkg-mod-libiconv
                else
                  final.libiconv;
            };

            pkg-mod-lerc = final.callPackage ./pkgs/lerc.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-lyra = final.callPackage ./pkgs/lyra.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-lz4 = final.callPackage ./pkgs/lz4.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-maplibre-native = final.callPackage ./pkgs/maplibre-native.nix {
              inherit static stdenv mkPackageName;
              sqlite = final.pkg-mod-sqlite;
              zlib = final.pkg-mod-zlib-compat;
              qtbase =
                if (stdenv.hostPlatform.isWindows or false) then final.pkg-mod-qtbase else final.qt6.qtbase;
              icu = final.pkg-mod-icu;
            };

            pkg-mod-minizip = final.callPackage ./pkgs/minizip.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
            };

            pkg-mod-netcdf = final.callPackage ./pkgs/netcdf.nix {
              inherit static stdenv mkPackageName;
              hdf5 = final.pkg-mod-hdf5;
              zlib = final.pkg-mod-zlib-compat;
              tinyxml2 = final.pkg-mod-tinyxml-2;
            };

            pkg-mod-netcdf-cxx4 = final.callPackage ./pkgs/netcdf-cxx4.nix {
              inherit static stdenv mkPackageName;
              hdf5 = final.pkg-mod-hdf5;
              netcdf = final.pkg-mod-netcdf;
            };

            pkg-mod-netcdf-fortran = final.callPackage ./pkgs/netcdf-fortran.nix {
              inherit static stdenv mkPackageName;
              hdf5 = final.pkg-mod-hdf5;
              netcdf = final.pkg-mod-netcdf;
            };

            pkg-mod-onetbb = final.callPackage ./pkgs/onetbb.nix {
              inherit static stdenv mkPackageName;
              hwloc = final.pkg-mod-hwloc;
            };

            pkg-mod-openssl = final.callPackage ./pkgs/openssl.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
            };

            pkg-mod-pcre2 = final.callPackage ./pkgs/pcre2.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-pcraster = final.callPackage ./pkgs/pcraster.nix {
              inherit static stdenv mkPackageName;
              gdal = final.pkg-mod-gdal;
              qtbase = final.pkg-mod-qtbase-headless;
              boost = final.pkg-mod-boost;
              xerces-c = final.pkg-mod-xerces-c;
              ncurses = final.ncurses;
              withPython = false;
            };

            pkg-mod-proj = final.callPackage ./pkgs/proj.nix {
              inherit static stdenv mkPackageName;
              sqlite = final.pkg-mod-sqlite;
            };

            pkg-mod-qhull = final.callPackage ./pkgs/qhull.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-qtbase =
              let
                host = stdenv.hostPlatform;
                isMinGW = (host.isMinGW or false) || (host.config or "" == "x86_64-w64-mingw32");
                isMusl = host.isMusl or false;

                # Desktop OpenGL provider for the GUI build:
                #  • Linux : the NixOS GL stack (libglvnd). The vendor driver
                #            is resolved at runtime from /run/opengl-driver/lib,
                #            so we only link the dispatch library at build time.
                #  • MinGW : null — opengl32 ships with the cross toolchain and
                #            is picked up automatically.
                #  • Darwin: null — OpenGL is provided by the system frameworks;
                #  • musl  : null — kept headless for now.
                guiLibGL = if (isMinGW || isMusl || host.isDarwin) then null else final.libGL;

                # Wayland QPA stack, linked dynamically on glibc Linux GUI
                # builds. Null on MinGW/Darwin/musl where it isn't used.
                isLinuxGlibc = !(isMinGW || isMusl || host.isDarwin);
                waylandDeps =
                  if isLinuxGlibc then
                    {
                      wayland = final.wayland;
                      wayland-scanner = final.buildPackages.wayland-scanner;
                      libxkbcommon = final.libxkbcommon;
                      libdrm = final.libdrm;
                      libgbm = final.libgbm or final.mesa;
                    }
                  else
                    {
                      wayland = null;
                      wayland-scanner = null;
                      libxkbcommon = null;
                      libdrm = null;
                      libgbm = null;
                    };

                sharedDeps = {
                  openssl = final.pkg-mod-openssl;
                  pcre2 = final.pkg-mod-pcre2;
                  zlib = final.pkg-mod-zlib-compat;
                  zstd = final.pkg-mod-zstd;
                  icu = final.pkg-mod-icu;
                };
              in
              final.callPackage ./pkgs/qtbase.nix (
                sharedDeps
                // waylandDeps
                // {
                  inherit static stdenv mkPackageName;
                  gui = true;
                  qtbase = final.qt6.qtbase.override (sharedDeps // { libGL = guiLibGL; });
                  qtbaseNative = final.buildPackages.qt6.qtbase;
                  sqlite = final.pkg-mod-sqlite;
                  libpng = final.pkg-mod-libpng;
                  libjpeg = final.pkg-mod-libjpeg;
                  libGL = guiLibGL;
                  cups = final.cups;
                }
              );

            # Same build without the GUI/Widgets/OpenGL stack.
            pkg-mod-qtbase-headless = final.pkg-mod-qtbase.override {
              gui = false;
              cups = null;
            };

            pkg-mod-qwt = final.callPackage ./pkgs/qwt.nix {
              inherit static stdenv mkPackageName;
              qtbase = final.pkg-mod-qtbase;
            };

            pkg-mod-reproc = final.callPackage ./pkgs/reproc.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-shapelib = final.callPackage ./pkgs/shapelib.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-scnlib = final.callPackage ./pkgs/scnlib.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-spdlog = final.callPackage ./pkgs/spdlog.nix {
              inherit static stdenv mkPackageName;
              fmt = final.pkg-mod-fmt;
            };

            pkg-mod-sqlite = final.callPackage ./pkgs/sqlite.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
            };

            pkg-mod-sqlpp11 = final.callPackage ./pkgs/sqlpp11.nix {
              inherit static stdenv mkPackageName;
              withSqlite = true;
              sqlite3 = final.pkg-mod-sqlite;
              howard-hinnant-date = final.pkg-mod-howard-hinnant-date.dev;
            };

            pkg-mod-tinyxml-2 = final.callPackage ./pkgs/tinyxml-2.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-type_safe = final.callPackage ./pkgs/type_safe.nix {
              inherit static stdenv mkPackageName;
              debug_assert = final.pkg-mod-debug_assert;
            };

            pkg-mod-tomlplusplus = final.callPackage ./pkgs/tomlplusplus.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-vc = final.callPackage ./pkgs/vc.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-zlib-compat = final.callPackage ./pkgs/zlib-ng.nix {
              inherit static stdenv mkPackageName;
              withZlibCompat = true;
            };

            pkg-mod-xerces-c = final.callPackage ./pkgs/xerces-c.nix {
              inherit static stdenv mkPackageName;
              xercesc = final.xercesc;
              icu = final.pkg-mod-icu;
            };

            pkg-mod-xz = final.callPackage ./pkgs/xz.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-zstd = final.callPackage ./pkgs/zstd.nix {
              inherit static stdenv mkPackageName;
            };

            windows =
              (prev.windows or { })
              // (
                if (final.stdenv.hostPlatform.isWindows or false) then
                  {
                    mcfgthreads = final.callPackage ./pkgs/mcfgthreads.nix {
                      inherit static stdenv;
                      mcfgthreads = prev.windows.mcfgthreads;
                    };
                  }
                else
                  { }
              );
          }
        );

      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      forEachSupportedSystem =
        f:
        inputs.nixpkgs.lib.genAttrs supportedSystems (
          system: f { pkgs = import inputs.nixpkgs { inherit system; }; }
        );

      forEachPkgMod =
        {
          pkgs,
          mkName ? (name: name),
          requireMingwSupport ? false,
          excludeNames ? [ ],
        }:

        if pkgs == null then
          { }
        else
          let
            names = builtins.filter (
              name:
              nixpkgs.lib.hasPrefix "pkg-mod-" name
              && !(builtins.elem name excludeNames)
              && (
                if requireMingwSupport then
                  let
                    pkg = pkgs.${name};
                  in
                  # Fix: ensure we test for the actual attribute name `mingwSupport`
                  # instead of using the boolean `requireMingwSupport` as an attr name.
                  if pkg ? mingwSupport then pkg.mingwSupport else true
                else
                  true
              )
            ) (builtins.attrNames pkgs);
          in
          builtins.listToAttrs (
            map (name: {
              name = mkName name;
              value = pkgs.${name};
            }) names
          );

      zigCrossCheckExclusions = [
        "pkg-mod-maplibre-native-static"
        "pkg-mod-netcdf-fortran-static"
        "pkg-mod-pcraster-static"
        "pkg-mod-qtbase-headless-static"
        "pkg-mod-qtbase-static"
        "pkg-mod-qwt-static"
      ];

      # Keep Qt and packages that depend on it out of musl and MinGW checks.
      qtCheckExclusions = [
        # musl
        "pkg-mod-pcraster-musl-static"
        "pkg-mod-qtbase-headless-musl-static"

        # MinGW
        "pkg-mod-maplibre-native-win-static"
        "pkg-mod-pcraster-win-static"
        "pkg-mod-qtbase-headless-win-static"
        "pkg-mod-qtbase-win-static"
        "pkg-mod-qwt-win-static"
      ];

      isZigPackage = _name: package: package.stdenv.cc.isZig or false;

      mkZigCrossCheck =
        system: packages:
        let
          pkgs = import nixpkgs { inherit system; };
          zigPackages = inputs.nixpkgs.lib.filterAttrs (
            name: package: isZigPackage name package && !(builtins.elem name zigCrossCheckExclusions)
          ) packages;
          links = inputs.nixpkgs.lib.mapAttrsToList (name: path: { inherit name path; }) zigPackages;
        in
        pkgs.linkFarm "zig-cross-packages-${system}" links;

      mkBuildEnvWith =
        {
          system,
          glibcVersion ? "2.28",
        }:
        let
          # We only support musl on Linux; Darwin will keep its native libc
          isLinux = builtins.elem system [
            "x86_64-linux"
            "aarch64-linux"
          ];

          pkgsBase = import nixpkgs {
            inherit system;
            config.strictDeps = true;
          };

          dynamicOverlay = mkOverlay {
            static = false;
          };

          staticOverlay = mkOverlay {
            static = true;
          };

          pkgsStaticGlibcBase =
            if isLinux then
              import nixpkgs {
                localSystem = system;
                crossSystem = pkgsBase.stdenv.hostPlatform // {
                  useZig = true;
                  linker = "lld";
                };
                crossOverlays = [
                  (final: _prev: {
                    # Some nixpkgs dependencies add this hook when target
                    # binaries are not executable. Deliberately leave it empty:
                    # portable outputs must never be run through an emulator.
                    mesonEmulatorHook = final.buildPackages.makeSetupHook {
                      name = "disable-target-execution";
                    } (final.buildPackages.writeText "disable-target-execution.sh" "");
                  })
                ];
                config = {
                  strictDeps = true;
                  replaceCrossStdenv =
                    {
                      buildPackages,
                      baseStdenv,
                    }:
                    mkZigCrossGlibcStdenv {
                      inherit buildPackages baseStdenv glibcVersion;
                    };
                };
              }
            else
              pkgsBase;

          pkgsDynamicGlibc = pkgsBase.extend dynamicOverlay;
          pkgsStaticGlibc = pkgsStaticGlibcBase.extend staticOverlay;
          pkgsStaticMusl = if isLinux then pkgsBase.pkgsStatic.extend staticOverlay else null;
        in
        {
          pkgsDefault = pkgsDynamicGlibc;
          pkgsStatic = pkgsStaticGlibc;
          pkgsStaticMusl = pkgsStaticMusl;
        };

      # Keep the original API while providing a configurable glibc baseline.
      mkBuildEnv = system: mkBuildEnvWith { inherit system; };

      mkBuildEnvMingwCross =
        system:
        {
          llvm ? false,
        }:
        let
          # MinGW cross-compilation is only supported from Linux build hosts.
          # Darwin can't be used to cross-compile to Windows here because the
          # toolchain pulls in `wine` as the build-time emulator, and wine is
          # not available on (aarch64-)darwin, which makes evaluation fail.
          isLinux = builtins.elem system [
            "x86_64-linux"
            "aarch64-linux"
          ];

          pkgsBase = import nixpkgs {
            inherit system;
            config.strictDeps = true;
          };

          # Cross-compiled static libraries for MinGW (x86_64-w64-mingw32)
          pkgsMingwCross =
            if !isLinux then
              null
            else
              import nixpkgs {
                inherit system;
                config = {
                  # strictDeps = true;
                  # allowUnsupportedSystem = true;
                };
                crossSystem = {
                  config = "x86_64-w64-mingw32";
                  useLLVM = llvm;
                  #linker = if llvm then "lld" else "ld.gold";
                };
                overlays = [
                  mingwOverlay
                  (mkOverlay { static = true; })
                ];
              };
        in
        {
          pkgsDefault = pkgsBase;
          pkgsMingw = pkgsMingwCross;
        };
    in
    {
      # A "normal" overlay (no parameters): used by nix tooling / flake check
      overlays.default = mkOverlay { static = false; };

      # Package overrides only. Consumers that need the versioned Zig/glibc
      # cross stdenv should use lib.mkBuildEnv or lib.mkBuildEnvWith.
      overlays.forStatic = mkOverlay { static = true; };

      lib.mkOverlay = mkOverlay;
      lib.mkZigCrossGlibcStdenv = mkZigCrossGlibcStdenv;
      lib.mkBuildEnv = mkBuildEnv;
      lib.mkBuildEnvWith = mkBuildEnvWith;
      lib.mkBuildEnvMingwCross = mkBuildEnvMingwCross;

      packages = builtins.listToAttrs (
        map (system: {
          name = system;
          value =
            let
              buildEnv = mkBuildEnv system;
              buildEnvMingw = mkBuildEnvMingwCross system { llvm = false; };

              dynamicAttrs =
                if
                  builtins.elem system [
                    "x86_64-linux"
                    "aarch64-linux"
                  ]
                then
                  let
                    # Build PCRaster directly against the pinned, unmodified
                    # nixpkgs dependencies rather than the pkg-mod overlay.
                    pkgsDynamicBase = import nixpkgs {
                      inherit system;
                      config.strictDeps = true;
                    };
                  in
                  {
                    pcraster = pkgsDynamicBase.callPackage ./pkgs/pcraster.nix {
                      static = false;
                      withPython = false;
                      mkPackageName =
                        pkg: _static: _stdenv:
                        pkg;
                      qtbase = pkgsDynamicBase.qt6.qtbase;
                      xerces-c = pkgsDynamicBase.xercesc;
                    };
                  }
                else
                  { };

              pkgsStaticGlibc = buildEnv.pkgsStatic;
              pkgsStaticMusl = buildEnv.pkgsStaticMusl;
              pkgsMingwCross = buildEnvMingw.pkgsMingw;

              staticAttrs = forEachPkgMod {
                pkgs = pkgsStaticGlibc;
                mkName = name: "${name}-static";
              };

              muslAttrs = forEachPkgMod {
                pkgs = pkgsStaticMusl;
                mkName = name: "${name}-musl-static";
                # The GUI qtbase isn't supported on musl; only the headless
                # variant (pkg-mod-qtbase-headless) is built there.
                excludeNames = [
                  "pkg-mod-qtbase"
                  "pkg-mod-qwt"
                  "pkg-mod-maplibre-native"
                ];
              };

              winAttrs = forEachPkgMod {
                pkgs = pkgsMingwCross;
                mkName = name: "${name}-win-static";
                requireMingwSupport = true;
              };
            in
            dynamicAttrs // staticAttrs // muslAttrs // winAttrs;
        }) systems
      );

      checks = builtins.mapAttrs (
        system: packages:
        let
          # Zig packages are covered by the aggregate check below. Keeping
          # them as individual checks would also build the excluded Qt stack.
          nonZigPackages = inputs.nixpkgs.lib.filterAttrs (
            name: package: !(isZigPackage name package) && !(builtins.elem name qtCheckExclusions)
          ) packages;
        in
        nonZigPackages
        // {
          # Qt and its consumers are excluded, as is netcdf-fortran because
          # Zig has no Fortran frontend and would pull in a source-built GCC.
          zig-cross-packages = mkZigCrossCheck system packages;
        }
      ) self.packages;

      devShells = forEachSupportedSystem (
        { pkgs, ... }:
        {
          default = pkgs.mkShell {
            name = "dev";
            packages =
              with pkgs;
              [
                cachix
                nixd
                nixfmt
                nix-output-monitor
              ]
              ++ (if pkgs.stdenv.hostPlatform.system == "aarch64-darwin" then [ ] else [ gdb ]);
            shellHook = ''
              geo_overlay_token="$(cat /run/secrets/cachix_geo_overlay_auth_token 2>/dev/null || true)"
              if [ -n "$geo_overlay_token" ]; then
                export CACHIX_AUTH_TOKEN="$geo_overlay_token"
              fi
              unset geo_overlay_token
            '';
          };
        }
      );
    };
}
