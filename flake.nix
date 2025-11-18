{
  description = "Reusable static overrides for various libraries";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-25.05";

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [
        "x86_64-linux"
        "aarch64-linux"
        "x86_64-darwin"
        "aarch64-darwin"
      ];

      customPackages = [
        "pkg-fmt"
        "pkg-gdal"
        "pkg-indicators"
        "pkg-libgeotiff"
        "pkg-libjpeg"
        "pkg-libpng"
        "pkg-libtiff"
        "pkg-lyra"
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
          pkg-fmt = final.callPackage ./pkgs/fmt.nix {
            inherit static;
          };

          pkg-gdal = final.callPackage ./pkgs/gdal.nix {
            inherit static;
            libpng = final.pkg-libpng;
            libtiff = final.pkg-libtiff;
            zlib = final.pkg-zlib-compat;
            xz = final.pkg-xz;
            zstd = final.pkg-zstd;
          };

          pkg-indicators = final.callPackage ./pkgs/indicators.nix {
            inherit static;
          };

          pkg-libgeotiff = final.callPackage ./pkgs/libgeotiff.nix {
            inherit static;
            libtiff = final.pkg-libtiff;
            proj = final.pkg-proj;
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
            zlib = final.pkg-zlib-compat;
            xz = final.pkg-xz;
            zstd = final.pkg-zstd;
          };

          pkg-lyra = final.callPackage ./pkgs/lyra.nix {
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
            inherit (prev) zstd;
            inherit static;
          };
        });

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
    };
}
