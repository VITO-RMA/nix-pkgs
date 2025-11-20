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
        "pkg-fmt"
        "pkg-curl"
        "pkg-expat"
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
          clib = if stdenv.hostPlatform.isStatic then "musl" else "glibc";
          suffix = if static then "-static" else "";
        in
        "${pkg}-mod${suffix}-${clib}";

      mkOverlay =
        static:

        (final: prev: {
          pkg-cryptopp = final.callPackage ./pkgs/cryptopp.nix {
            inherit static mkPackageName;
          };

          pkg-curl = final.callPackage ./pkgs/curl.nix {
            inherit static mkPackageName;
            openssl = final.pkg-openssl;
            zlib = final.pkg-zlib-compat;
            zstd = final.pkg-zstd;
          };

          pkg-expat = final.callPackage ./pkgs/expat.nix {
            inherit static mkPackageName;
          };

          pkg-fmt = final.callPackage ./pkgs/fmt.nix {
            inherit static mkPackageName;
          };

          pkg-gdal = final.callPackage ./pkgs/gdal.nix {
            inherit static mkPackageName;
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
            inherit static mkPackageName;
          };

          pkg-howard-hinnant-date = final.callPackage ./pkgs/howard-hinnant-date.nix {
            inherit static mkPackageName;
          };

          pkg-hwloc = final.callPackage ./pkgs/hwloc.nix {
            inherit static mkPackageName;
          };

          pkg-indicators = final.callPackage ./pkgs/indicators.nix {
            inherit static mkPackageName;
          };

          pkg-json_c = final.callPackage ./pkgs/json_c.nix {
            inherit static mkPackageName;
          };

          pkg-libdeflate = final.callPackage ./pkgs/libdeflate.nix {
            inherit static mkPackageName;
            zlib = final.pkg-zlib-compat;
          };

          pkg-libexpat = final.callPackage ./pkgs/libexpat.nix {
            inherit static mkPackageName;
          };

          pkg-libgeotiff = final.callPackage ./pkgs/libgeotiff.nix {
            inherit static mkPackageName;
            libtiff = final.pkg-libtiff;
            lerc = final.pkg-lerc;
            proj = final.pkg-proj;
            zlib = final.pkg-zlib-compat;
            zstd = final.pkg-zstd;
          };

          pkg-libjpeg = final.callPackage ./pkgs/libjpeg.nix {
            inherit static mkPackageName;
          };

          pkg-libpng = final.callPackage ./pkgs/libpng.nix {
            inherit static mkPackageName;
            zlib = final.pkg-zlib-compat;
          };

          pkg-libtiff = final.callPackage ./pkgs/libtiff.nix {
            inherit static mkPackageName;
            lerc = final.pkg-lerc;
            libdeflate = final.pkg-libdeflate;
            zlib = final.pkg-zlib-compat;
            xz = final.pkg-xz;
            zstd = final.pkg-zstd;
          };

          pkg-libxlsxwriter = final.callPackage ./pkgs/libxlsxwriter.nix {
            inherit static mkPackageName;
            zlib = final.pkg-zlib-compat;
            minizip = final.pkg-minizip;
          };

          pkg-lerc = final.callPackage ./pkgs/lerc.nix {
            inherit static mkPackageName;
          };

          pkg-lyra = final.callPackage ./pkgs/lyra.nix {
            inherit static mkPackageName;
          };

          pkg-lz4 = final.callPackage ./pkgs/lz4.nix {
            inherit static mkPackageName;
          };

          pkg-minizip = final.callPackage ./pkgs/minizip.nix {
            inherit static mkPackageName;
            zlib = final.pkg-zlib-compat;
          };

          pkg-onetbb = final.callPackage ./pkgs/onetbb.nix {
            inherit static mkPackageName;
            hwloc = final.pkg-hwloc;
          };

          pkg-openssl = final.callPackage ./pkgs/openssl.nix {
            inherit static mkPackageName;
            zlib = final.pkg-zlib-compat;
          };

          pkg-pcre2 = final.callPackage ./pkgs/pcre2.nix {
            inherit static mkPackageName;
          };

          pkg-proj = final.callPackage ./pkgs/proj.nix {
            inherit static mkPackageName;
            sqlite = final.pkg-sqlite;
          };

          pkg-spdlog = final.callPackage ./pkgs/spdlog.nix {
            inherit static mkPackageName;
            fmt = final.pkg-fmt;
          };

          pkg-sqlite = final.callPackage ./pkgs/sqlite.nix {
            inherit static mkPackageName;
            zlib = final.pkg-zlib-compat;
          };

          pkg-type_safe = final.callPackage ./pkgs/type_safe.nix {
            inherit static mkPackageName;
          };

          pkg-tomlplusplus = final.callPackage ./pkgs/tomlplusplus.nix {
            inherit static mkPackageName;
          };

          pkg-vc = final.callPackage ./pkgs/vc.nix {
            inherit static mkPackageName;
          };

          pkg-zlib-compat = final.callPackage ./pkgs/zlib-ng.nix {
            inherit static mkPackageName;
            withZlibCompat = true;
          };

          pkg-xz = final.callPackage ./pkgs/xz.nix {
            inherit static mkPackageName;
          };

          pkg-zstd = final.callPackage ./pkgs/zstd.nix {
            inherit static mkPackageName;
          };
        });

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

      # Build a package set for one system (dynamic or static)
      mkPkgs =
        system: static:
        import nixpkgs {
          inherit system;
          overlays = [ (mkOverlay static) ];
        };
    in
    {
      # A "normal" overlay (no parameters): used by nix tooling / flake check
      overlays.default = mkOverlay false;

      # A factory that *you* can use from consumer flakes:
      # overlays applied as: (static-pkgs.overlayForStatic true)
      overlayForStatic = mkOverlay;

      packages = builtins.listToAttrs (
        map (system: {
          name = system;
          value =
            let
              pkgsDynamic = mkPkgs system false;
              pkgsStatic = mkPkgs system true;
            in
            builtins.listToAttrs (
              map (pkgName: {
                name = pkgName;
                value = pkgsDynamic.${pkgName};
              }) customPackages
            )
            // builtins.listToAttrs (
              map (pkgName: {
                name = "${pkgName}-static";
                value = pkgsStatic.${pkgName};
              }) customPackages
            );
        }) systems
      );

      checks = builtins.listToAttrs (
        map (system: {
          name = system;
          value =
            builtins.listToAttrs (
              map (pkgName: {
                name = pkgName;
                value = self.packages.${system}.${pkgName};
              }) customPackages
            )
            // builtins.listToAttrs (
              map (pkgName: {
                name = "${pkgName}-static";
                value = self.packages.${system}."${pkgName}-static";
              }) customPackages
            );
        }) systems
      );

      devShells = forEachSupportedSystem (
        { pkgs, ... }:
        {
          default =
            pkgs.mkShell.override
              {
                # Override stdenv in order to change compiler:
                # stdenv = pkgs.clangStdenv;
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
