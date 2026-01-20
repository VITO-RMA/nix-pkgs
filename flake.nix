{
  description = "Reusable static overrides for various libraries";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.11";

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
            else
              "-glibc";
          suffix = if static && !(stdenv.hostPlatform.isStatic) then "-static" else "";
        in
        "${pkg}${suffix}${clib}";

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
              gccWin32 = buildPkgs.wrapCCWith {
                cc = buildPkgs.gcc-unwrapped.override {
                  # if you still want this:
                  # threadsCross = {
                  #   model = "win32";
                  #   package = null;
                  # };
                };
              };

              stdenvWin = prev.overrideCC baseStdenv gccWin32;
            in
            {
              # make this the stdenv for MinGW target12s
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

            pkg-mod-cryptopp = final.callPackage ./pkgs/cryptopp.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-curl = final.callPackage ./pkgs/curl.nix {
              inherit static stdenv mkPackageName;
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

            pkg-mod-gdal = final.callPackage ./pkgs/gdal.nix {
              inherit static stdenv mkPackageName;
              useMinimalFeatures = false;
              useArmadillo = false; # armadillo doesn't support static builds
              useArrow = false; # arrow doesn't support static builds well
              useTiledb = false; # tiledb doesn't support Windows
              usePostgres = false; # libpq doesn't support Windows
              useCurl = false; # curl dependencies don't support Windows
              useNetCDF = true; # netcdf doesn't support Windows well
              useHDF = false; # hdf doesn't support Windows well
              useQhull = false; # qhull doesn't support Windows
              useCBlosc = false; # c-blosc fails to compile on Windows
              curl = final.pkg-mod-curl;
              cryptopp = final.pkg-mod-cryptopp;
              c-blosc = final.c-blosc; # not overridden here yet
              expat = final.pkg-mod-expat;
              geos = final.pkg-mod-geos;
              json_c = final.pkg-mod-json_c;
              lerc = final.pkg-mod-lerc;
              libdeflate = final.pkg-mod-libdeflate;
              libpng = final.pkg-mod-libpng;
              libtiff = final.pkg-mod-libtiff;
              libgeotiff = final.pkg-mod-libgeotiff;
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
              cryptopp = final.pkg-mod-cryptopp;
              c-blosc = final.c-blosc; # not overridden here yet
              expat = final.pkg-mod-expat;
              geos = final.pkg-mod-geos;
              json_c = final.pkg-mod-json_c;
              lerc = final.pkg-mod-lerc;
              libdeflate = final.pkg-mod-libdeflate;
              libpng = final.pkg-mod-libpng;
              libtiff = final.pkg-mod-libtiff;
              libgeotiff = final.pkg-mod-libgeotiff;
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

            pkg-mod-libgeotiff = final.callPackage ./pkgs/libgeotiff.nix {
              inherit static stdenv mkPackageName;
              libtiff = final.pkg-mod-libtiff;
              lerc = final.pkg-mod-lerc;
              proj = final.pkg-mod-proj;
              zlib = final.pkg-mod-zlib-compat;
              zstd = final.pkg-mod-zstd;
            };

            pkg-mod-libjpeg = final.callPackage ./pkgs/libjpeg.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-mod-libpng = final.callPackage ./pkgs/libpng.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
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
              qtbase = final.qt6.qtbase;
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

            pkg-mod-proj = final.callPackage ./pkgs/proj.nix {
              inherit static stdenv mkPackageName;
              sqlite = final.pkg-mod-sqlite;
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
        }:

        if pkgs == null then
          { }
        else
          let
            names = builtins.filter (
              name:
              nixpkgs.lib.hasPrefix "pkg-mod-" name
              && name != "pkg-mod-maplibre-native"
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

      mkBuildEnv =
        system:
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

          pkgsDynamicGlibc = pkgsBase.extend dynamicOverlay;
          pkgsStaticGlibc = pkgsBase.extend staticOverlay;
          pkgsStaticMusl = if isLinux then pkgsBase.pkgsStatic.extend staticOverlay else null;
        in
        {
          pkgsDefault = pkgsDynamicGlibc;
          pkgsStatic = pkgsStaticGlibc;
          pkgsStaticMusl = pkgsStaticMusl;
        };

      mkBuildEnvMingwCross =
        system:
        {
          llvm ? false,
        }:
        let
          pkgsBase = import nixpkgs {
            inherit system;
            config.strictDeps = true;
          };

          # Cross-compiled static libraries for MinGW (x86_64-w64-mingw32)
          pkgsMingwCross = import nixpkgs {
            inherit system;
            config.strictDeps = true;
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

      # A factory that *you* can use from consumer flakes:
      # overlays applied as: (static-pkgs.overlayForStatic true)
      overlays.forStatic = mkOverlay { static = true; };

      lib.mkOverlay = mkOverlay;
      lib.mkBuildEnv = mkBuildEnv;
      lib.mkBuildEnvMingwCross = mkBuildEnvMingwCross;

      packages = builtins.listToAttrs (
        map (system: {
          name = system;
          value =
            let
              buildEnv = mkBuildEnv system;
              buildEnvMingw = mkBuildEnvMingwCross system { llvm = false; };

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
              };

              winAttrs = forEachPkgMod {
                pkgs = pkgsMingwCross;
                mkName = name: "${name}-win-static";
                requireMingwSupport = true;
              };
            in
            staticAttrs // muslAttrs // winAttrs;
        }) systems
      );

      checks = self.packages;

      devShells = forEachSupportedSystem (
        { pkgs, ... }:
        {
          default = pkgs.mkShell {
            name = "dev";
            packages =
              with pkgs;
              [
                nil
                nixfmt-rfc-style
              ]
              ++ (if pkgs.system == "aarch64-darwin" then [ ] else [ gdb ]);
          };
        }
      );
    };
}
