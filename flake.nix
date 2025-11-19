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
        "pkg-geos"
        "pkg-indicators"
        "pkg-json_c"
        "pkg-libdeflate"
        "pkg-libgeotiff"
        "pkg-libjpeg"
        "pkg-libpng"
        "pkg-libtiff"
        "pkg-lerc"
        "pkg-lyra"
        "pkg-lz4"
        "pkg-openssl"
        "pkg-pcre2"
        "pkg-proj"
        "pkg-spdlog"
        "pkg-sqlite"
        "pkg-type_safe"
        "pkg-zlib-compat"
        "pkg-zstd"
        "pkg-xz"
      ];

      mkOverlay =
        static:

        (final: prev: {
          pkg-cryptopp = final.callPackage ./pkgs/cryptopp.nix {
            inherit (prev) cryptopp;
            inherit static;
          };

          pkg-curl = final.callPackage ./pkgs/curl.nix {
            inherit (prev) curl;
            inherit static;
            openssl = final.pkg-openssl;
            zlib = final.pkg-zlib-compat;
            zstd = final.pkg-zstd;
          };

          pkg-expat = final.callPackage ./pkgs/expat.nix {
            inherit static;
          };

          pkg-fmt = final.callPackage ./pkgs/fmt.nix {
            inherit static;
          };

          pkg-gdal = final.callPackage ./pkgs/gdal.nix {
            inherit static;
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
            inherit (prev) geos;
            inherit static;
          };

          pkg-indicators = final.callPackage ./pkgs/indicators.nix {
            inherit static;
          };

          pkg-json_c = final.callPackage ./pkgs/json_c.nix {
            inherit (prev) json_c;
            inherit static;
          };

          pkg-libdeflate = final.callPackage ./pkgs/libdeflate.nix {
            inherit (prev) libdeflate;
            inherit static;
            zlib = final.pkg-zlib-compat;
          };

          pkg-libexpat = final.callPackage ./pkgs/libexpat.nix {
            inherit (prev) expat;
            inherit static;
          };

          pkg-libgeotiff = final.callPackage ./pkgs/libgeotiff.nix {
            inherit static;
            libtiff = final.pkg-libtiff;
            lerc = final.pkg-lerc;
            proj = final.pkg-proj;
            zlib = final.pkg-zlib-compat;
            zstd = final.pkg-zstd;
          };

          pkg-libjpeg = final.callPackage ./pkgs/libjpeg.nix {
            inherit (prev) libjpeg;
            inherit static;
          };

          pkg-libpng = final.callPackage ./pkgs/libpng.nix {
            inherit (prev) libpng;
            inherit static;
            zlib = final.pkg-zlib-compat;
          };

          pkg-libtiff = final.callPackage ./pkgs/libtiff.nix {
            inherit (prev) libtiff;
            inherit static;
            lerc = final.pkg-lerc;
            libdeflate = final.pkg-libdeflate;
            zlib = final.pkg-zlib-compat;
            xz = final.pkg-xz;
            zstd = final.pkg-zstd;
          };

          pkg-lerc = final.callPackage ./pkgs/lerc.nix {
            inherit (prev) lerc;
            inherit static;
          };

          pkg-lyra = final.callPackage ./pkgs/lyra.nix {
            inherit static;
          };

          pkg-lz4 = final.callPackage ./pkgs/lz4.nix {
            inherit (prev) lz4;
            inherit static;
          };

          pkg-openssl = final.callPackage ./pkgs/openssl.nix {
            inherit (prev) openssl;
            inherit static;
            zlib = final.pkg-zlib-compat;
          };

          pkg-pcre2 = final.callPackage ./pkgs/pcre2.nix {
            inherit (prev) pcre2;
            inherit static;
          };

          pkg-proj = final.callPackage ./pkgs/proj.nix {
            inherit static;
            sqlite = final.pkg-sqlite;
          };

          pkg-spdlog = final.callPackage ./pkgs/spdlog.nix {
            inherit static;
            fmt = final.pkg-fmt;
          };

          pkg-sqlite = final.callPackage ./pkgs/sqlite.nix {
            inherit (prev) sqlite;
            inherit static;
            zlib = final.pkg-zlib-compat;
          };

          pkg-type_safe = final.callPackage ./pkgs/type_safe.nix {
            inherit static;
          };

          pkg-zlib-compat = final.callPackage ./pkgs/zlib-ng.nix {
            inherit static;
            withZlibCompat = true;
          };

          pkg-xz = final.callPackage ./pkgs/xz.nix {
            inherit (prev) xz;
            inherit static;
          };

          pkg-zstd = final.callPackage ./pkgs/zstd.nix {
            inherit static;
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
          system:
          f {
            pkgs = import inputs.nixpkgs {
              inherit system;
            };
          }
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
                    # development tools
                    # cmake
                    #ninja
                  ]
                  ++ (if pkgs.system == "aarch64-darwin" then [ ] else [ gdb ]);
              };
        }
      );
    };
}
