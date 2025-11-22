{
  description = "Reusable static overrides for various libraries";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs =
    { self, nixpkgs, ... }@inputs:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      # we prepend the packages with pkg to avoid rebuilding the world
      # otherwise all the packages in the system that depend on one of these
      # packages would need to be rebuilt to link against the static version
      customPackages = [
        "pkg-cryptopp"
        "pkg-curl"
        "pkg-doctest"
        "pkg-eigen"
        "pkg-expat"
        "pkg-fmt"
        "pkg-gdal"
        "pkg-howard-hinnant-date"
        "pkg-geos"
        "pkg-indicators"
        "pkg-json_c"
        "pkg-libdeflate"
        "pkg-libgeotiff"
        "pkg-libjpeg"
        "pkg-libpng"
        "pkg-libtiff"
        "pkg-libxlsxwriter"
        "pkg-lerc"
        "pkg-lyra"
        "pkg-lz4"
        "pkg-minizip"
        "pkg-onetbb"
        "pkg-openssl"
        "pkg-pcre2"
        "pkg-proj"
        "pkg-spdlog"
        "pkg-sqlite"
        "pkg-tomlplusplus"
        "pkg-type_safe"
        "pkg-vc"
        "pkg-zlib-compat"
        "pkg-zstd"
        "pkg-xz"
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
        "${pkg}-mod${suffix}${clib}";

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
              gccWin32 = buildPkgs.wrapCC (
                buildPkgs.gcc-unwrapped.override {
                  threadsCross = {
                    model = "win32";
                    package = null;
                  };
                }
              );
              stdenvWin = prev.overrideCC baseStdenv gccWin32;
            in
            {
              # make this the stdenv for MinGW targets
              stdenv = stdenvWin;
            };

      # mkOverlay is a function that creates a Nix overlay for overriding or adding packages.
      mkOverlay =
        static:
        (
          final: prev:
          let
            stdenv = prev.stdenv;
          in
          {
            pkg-cryptopp = final.callPackage ./pkgs/cryptopp.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-curl = final.callPackage ./pkgs/curl.nix {
              inherit static stdenv mkPackageName;
              openssl = final.pkg-openssl;
              zlib = final.pkg-zlib-compat;
              zstd = final.pkg-zstd;
            };

            pkg-doctest = final.callPackage ./pkgs/doctest.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-eigen = final.callPackage ./pkgs/eigen.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-expat = final.callPackage ./pkgs/expat.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-fmt = final.callPackage ./pkgs/fmt.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-gdal = final.callPackage ./pkgs/gdal.nix {
              inherit static stdenv mkPackageName;
              curl = final.pkg-curl;
              cryptopp = final.pkg-cryptopp;
              c-blosc = final.c-blosc; # not overridden here yet
              geos = final.pkg-geos;
              expat = final.pkg-expat;
              json_c = final.pkg-json_c;
              lerc = final.pkg-lerc;
              libdeflate = final.pkg-libdeflate;
              libpng = final.pkg-libpng;
              libtiff = final.pkg-libtiff;
              libgeotiff = final.pkg-libgeotiff;
              lz4 = final.pkg-lz4;
              openssl = final.pkg-openssl;
              pcre2 = final.pkg-pcre2;
              proj = final.pkg-proj;
              sqlite = final.pkg-sqlite;
              zlib = final.pkg-zlib-compat;
              xz = final.pkg-xz;
              zstd = final.pkg-zstd;
            };

            pkg-geos = final.callPackage ./pkgs/geos.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-howard-hinnant-date = final.callPackage ./pkgs/howard-hinnant-date.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-hwloc = final.callPackage ./pkgs/hwloc.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-indicators = final.callPackage ./pkgs/indicators.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-json_c = final.callPackage ./pkgs/json_c.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-libdeflate = final.callPackage ./pkgs/libdeflate.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-zlib-compat;
            };

            pkg-libexpat = final.callPackage ./pkgs/libexpat.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-libgeotiff = final.callPackage ./pkgs/libgeotiff.nix {
              inherit static stdenv mkPackageName;
              libtiff = final.pkg-libtiff;
              lerc = final.pkg-lerc;
              proj = final.pkg-proj;
              zlib = final.pkg-zlib-compat;
              zstd = final.pkg-zstd;
            };

            pkg-libjpeg = final.callPackage ./pkgs/libjpeg.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-libpng = final.callPackage ./pkgs/libpng.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-zlib-compat;
            };

            pkg-libtiff = final.callPackage ./pkgs/libtiff.nix {
              inherit static stdenv mkPackageName;
              lerc = final.pkg-lerc;
              libdeflate = final.pkg-libdeflate;
              zlib = final.pkg-zlib-compat;
              xz = final.pkg-xz;
              zstd = final.pkg-zstd;
            };

            pkg-libxlsxwriter = final.callPackage ./pkgs/libxlsxwriter.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-zlib-compat;
              minizip = final.pkg-minizip;
            };

            pkg-lerc = final.callPackage ./pkgs/lerc.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-lyra = final.callPackage ./pkgs/lyra.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-lz4 = final.callPackage ./pkgs/lz4.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-minizip = final.callPackage ./pkgs/minizip.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-zlib-compat;
            };

            pkg-onetbb = final.callPackage ./pkgs/onetbb.nix {
              inherit static stdenv mkPackageName;
              hwloc = final.pkg-hwloc;
            };

            pkg-openssl = final.callPackage ./pkgs/openssl.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-zlib-compat;
            };

            pkg-pcre2 = final.callPackage ./pkgs/pcre2.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-proj = final.callPackage ./pkgs/proj.nix {
              inherit static stdenv mkPackageName;
              sqlite = final.pkg-sqlite;
            };

            pkg-spdlog = final.callPackage ./pkgs/spdlog.nix {
              inherit static stdenv mkPackageName;
              fmt = final.pkg-fmt;
            };

            pkg-sqlite = final.callPackage ./pkgs/sqlite.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-zlib-compat;
            };

            pkg-type_safe = final.callPackage ./pkgs/type_safe.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-tomlplusplus = final.callPackage ./pkgs/tomlplusplus.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-vc = final.callPackage ./pkgs/vc.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-zlib-compat = final.callPackage ./pkgs/zlib-ng.nix {
              inherit static stdenv mkPackageName;
              withZlibCompat = true;
            };

            pkg-xz = final.callPackage ./pkgs/xz.nix {
              inherit static stdenv mkPackageName;
            };

            pkg-zstd = final.callPackage ./pkgs/zstd.nix {
              inherit static stdenv mkPackageName;
            };
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

          pkgsDynamicGlibc = pkgsBase.extend (mkOverlay false);
          pkgsStaticGlibc = pkgsBase.extend (mkOverlay true);
          pkgsStaticMusl = if isLinux then pkgsBase.pkgsStatic.extend (mkOverlay true) else null;
        in
        {
          pkgsDefault = pkgsDynamicGlibc;
          pkgsStatic = pkgsStaticGlibc;
          pkgsStaticMusl = pkgsStaticMusl;
        };

      mkBuildEnvMingwCross =
        system:
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
            };
            overlays = [
              mingwOverlay
              (mkOverlay true)
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
      overlays.default = mkOverlay false;

      # A factory that *you* can use from consumer flakes:
      # overlays applied as: (static-pkgs.overlayForStatic true)
      overlays.forStatic = mkOverlay true;

      lib.mkBuildEnv = mkBuildEnv;
      lib.mkBuildEnvMingwCross = mkBuildEnvMingwCross;

      packages = builtins.listToAttrs (
        map (system: {
          name = system;
          value =
            let
              buildEnv = mkBuildEnv system;
              buildEnvMingw = mkBuildEnvMingwCross system;

              pkgsStaticGlibc = buildEnv.pkgsStatic;
              pkgsStaticMusl = buildEnv.pkgsStaticMusl;
              pkgsMingwCross = buildEnvMingw.pkgsMingw;

              # Filter custom packages for MinGW based on mingwSupport attribute
              supportedMingwPackages = inputs.nixpkgs.lib.filter (
                pkgName:
                let
                  pkg = pkgsMingwCross.${pkgName};
                in
                if pkg ? mingwSupport then pkg.mingwSupport else true
              ) customPackages;

              staticAttrs = builtins.listToAttrs (
                map (pkgName: {
                  name = "${pkgName}-static";
                  value = pkgsStaticGlibc.${pkgName};
                }) customPackages
              );

              muslAttrs =
                if pkgsStaticMusl != null then
                  builtins.listToAttrs (
                    map (pkgName: {
                      name = "${pkgName}-musl-static";
                      value = pkgsStaticMusl.${pkgName};
                    }) customPackages
                  )
                else
                  { };

              winAttrs = builtins.listToAttrs (
                map (pkgName: {
                  name = "${pkgName}-win-static";
                  value = pkgsMingwCross.${pkgName};
                }) supportedMingwPackages
              );
            in
            staticAttrs // muslAttrs // winAttrs;
        }) systems
      );

      checks = builtins.listToAttrs (
        map (system: {
          name = system;
          value =
            let
              pkgsForSystem = self.packages.${system};

              baseChecks = builtins.listToAttrs (
                map (pkgName: {
                  name = "${pkgName}-static";
                  value = pkgsForSystem."${pkgName}-static";
                }) customPackages
              );

              muslChecks = builtins.listToAttrs (
                map (pkgName: {
                  name = "${pkgName}-musl-static";
                  value = pkgsForSystem."${pkgName}-musl-static";
                }) customPackages
              );

              winStaticPkgNames = builtins.filter (
                pkgName: pkgsForSystem ? "${pkgName}-win-static"
              ) customPackages;

              winStaticChecks = builtins.listToAttrs (
                map (pkgName: {
                  name = "${pkgName}-win-static";
                  value = pkgsForSystem."${pkgName}-win-static";
                }) winStaticPkgNames
              );
            in
            baseChecks
            // winStaticChecks
            // (
              if
                builtins.elem system [
                  "x86_64-linux"
                  "aarch64-linux"
                ]
              then
                muslChecks
              else
                { }
            );
        }) systems
      );

      devShells = forEachSupportedSystem (
        { pkgs, ... }:
        {
          default =
            pkgs.mkShell.override
              {
              }
              {
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
