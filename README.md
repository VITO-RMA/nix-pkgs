# nix-pkgs

Reusable Nix package overrides for building the same C/C++ dependency stack for native development, older glibc-based Linux distributions, fully static Linux deployments, and Windows.

Package attributes use the `pkg-mod-` prefix so they do not replace the corresponding nixpkgs packages or cause unrelated nixpkgs dependencies to be rebuilt.

## Use the overlay in a devenv project

Add this repository as an input in `devenv.yaml`:

```yaml
inputs:
  nixpkgs:
    follows: pkgs-mod/nixpkgs

  pkgs-mod:
    url: github:VITO-RMA/nix-pkgs/main
```

Apply the default overlay in `devenv.nix` and select packages through `pkgs`:

```nix
{ inputs, pkgs, ... }:

{
  overlays = [
    inputs.pkgs-mod.overlays.default
  ];

  packages = [
    pkgs.pkg-mod-fmt
    pkgs.pkg-mod-gdal
  ];
}
```

Enter the environment with:

```console
devenv shell
```

The default overlay provides the **dynamic native** variant. On Linux, that means shared-library builds using the devenv project's nixpkgs stdenv and glibc. On Darwin it means native Darwin builds instead; Darwin does not use glibc.

The direction of the `follows` declaration is intentional and is required to use the prebuilt packages from the `geo-overlay` Cachix cache: the devenv project's `nixpkgs` follows `pkgs-mod/nixpkgs`. Nix store paths depend on the complete build inputs, including the nixpkgs revision. If the project uses a newer or different nixpkgs revision, its compiler, glibc, and dependency derivations produce different store paths, causing Cachix cache misses and local rebuilds. Following `pkgs-mod/nixpkgs` keeps the project on the exact nixpkgs revision used to populate the cache.

## Build variants

### 1. Dynamic glibc

`overlays.default` applies the custom recipes with shared-library mode enabled. On Linux they use the normal nixpkgs compiler, linker, dynamic loader, and glibc from the nixpkgs revision used by devenv.

Use this variant for normal development inside Nix when deployment to a non-Nix Linux installation is not the goal. Executables built normally in this environment generally retain references to the Nix store, including its dynamic loader and shared libraries.

The shorthand “dynamic glibc libraries” describes the compiled library recipes. Some packages are header-only, and some packages also install selected command-line tools.

### 2. Static glibc compatibility

The static glibc variant builds the custom libraries as static archives using the repository's Zig-based cross stdenv. On Linux the target uses a **glibc 2.28 ABI baseline**.

This variant is intended for applications that need to run on older glibc-based distributions without depending on a Nix-store dynamic loader. There is an important distinction:

- A static archive such as `libfmt.a` is not itself linked to glibc.
- The archive is compiled with Zig's glibc 2.28 target and should be linked into the final application with the matching Zig toolchain.
- The resulting application is expected to use the target distribution's glibc dynamically and therefore requires glibc 2.28 or newer. It is not a fully static executable.

The final application and all of its dependencies must be built with the matching Zig compatibility toolchain to retain the older-glibc guarantee.

### 3. Static musl

The musl variant uses static libraries and static musl linkage. When the application and all of its dependencies use this variant, the resulting executable should not require a runtime libc or dynamic loader from the target distribution.

This variant is Linux-only. GUI Qt, Qwt, and MapLibre Native are currently omitted; the headless Qt variant remains available.

### 4. MinGW

The MinGW variant is cross-compiled from a Linux host for `x86_64-w64-mingw32`. The custom libraries are built in static mode, and the toolchain requests static GCC and C++ runtime linkage with `-static-libgcc` and `-static-libstdc++`.

It contains Windows libraries and, where a recipe enables tools, Windows executables. “Static” does not mean that a Windows executable has no DLL imports: Windows system libraries and APIs can still be dynamically imported.

The MinGW variant targets 64-bit Windows, is cross-compiled from Linux, and uses GCC by default.

## Current implementation status

The build definitions currently implement and export all four modes described above. Representative `fmt` outputs have the expected forms:

- dynamic glibc: ELF shared object (`libfmt.so`);
- static glibc compatibility: static archive (`libfmt.a`) built with the Zig stdenv;
- musl: static archive (`libfmt.a`) built with the static musl toolchain;
- MinGW: static archive (`libfmt.a`) for `x86_64-w64-mingw32`.

These descriptions are build-mode guarantees, not a claim that every package has the same output shape. Header-only packages have no linked library, some recipes install binaries, and final executable portability still depends on building the complete dependency closure with the matching toolchain.
