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
            if stdenv.hostPlatform.isWindows or false then
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
                  # Use win32 threads instead of posix mcfgthread:
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

      # createMsvcOverlay is the MSVC-ABI counterpart of `mingwOverlay`.
      #
      # Instead of GCC/MinGW it relies on the LLVM toolchain (clang / clang-cl
      # + lld-link) that nixpkgs wires up for the `x86_64-pc-windows-msvc`
      # cross target, producing MSVC-ABI binaries using the same backend that
      # powers `clang-cl`.
      #
      # nixpkgs ships the Windows SDK + CRT (via `xwin`, as `windows.sdk`) but
      # does *not* wire its header/library directories into the cross cc-wrapper
      # — the wrapper bakes in `-nostdlibinc` with nothing to compensate, so
      # even the `compiler-rt` bootstrap fails with `'stdlib.h' file not found`.
      # This overlay closes that gap by overriding `wrapCCWith` so every MSVC
      # clang wrapper (bootstrap stages included) gets the SDK search paths, and
      # optionally selects the static MSVC runtime.
      #
      # It is written as a factory (`createMsvcOverlay { ... }`) so callers can
      # choose whether to link the static MSVC runtime.
      createMsvcOverlay =
        {
          # Link the static MSVC runtime (libcmt) via `-fms-runtime-lib=static`
          # so produced binaries don't depend on the MSVC redistributable runtime DLLs.
          staticCrt ? true,
        }:
        final: prev:
        let
          baseStdenv = prev.stdenv or null;
        in
        # During early bootstrap `prev.stdenv` can be null or incomplete.
        if baseStdenv == null then
          { }
        else
          let
            lib = prev.lib;

            platformIsMsvc =
              p:
              (p.config or "" == "x86_64-pc-windows-msvc")
              || ((p.isWindows or false) && (p.abi.name or "" == "msvc"));

            # The cc-wrapper override must fire wherever an MSVC-targeting clang
            # wrapper is built. That includes `pkgsBuildHost` (where the cross
            # compiler that builds the LLVM toolchain lives), whose *host* is the
            # build machine but whose *target* is MSVC. So gate the wrapper
            # override on the target platform, and gate the stdenv replacement on
            # the host platform. Native (non-MSVC-targeting) sets such as
            # `pkgsBuildBuild` are left untouched, so host compilers never see
            # the Windows SDK headers.
            targetIsMsvc = platformIsMsvc baseStdenv.targetPlatform;
            hostIsMsvc = platformIsMsvc baseStdenv.hostPlatform;

            # `windows.sdk` is fetched for the *host* arch of whichever package
            # set evaluates it (xwin's `fetchWinSdk` derives the arch from
            # `stdenvNoCC.hostPlatform`). The wrapper is built in `pkgsBuildHost`,
            # whose host is the build machine (e.g. aarch64-linux), so
            # `prev.windows.sdk` there would download the *wrong* arch SDK and
            # the final link would fail with missing `*.lib` import libraries.
            # `targetPackages.windows.sdk` always resolves to the SDK whose arch
            # matches the MSVC *target* (x86_64), in both `pkgsBuildHost` and the
            # main cross set, so use that.
            sdk = prev.targetPackages.windows.sdk;

            # xwin `splat` uses MS arch notation for the per-arch lib dirs.
            target = baseStdenv.targetPlatform;
            archDir =
              if target.isx86_64 then
                "x64"
              else if target.isAarch64 then
                "arm64"
              else if target.isx86_32 then
                "x86"
              else
                throw "createMsvcOverlay: unsupported MSVC target arch ${target.config}";

            # The xwin `splat` layout of `windows.sdk`:
            #   <sdk>/crt/{include,lib/<arch>}         -> MSVC CRT (libcmt, ...)
            #   <sdk>/sdk/include/{ucrt,um,shared}     -> Windows SDK headers
            #   <sdk>/sdk/lib/{ucrt,um}/<arch>         -> Windows SDK import libs
            includeDirs = [
              "crt/include"
              "sdk/include/ucrt"
              "sdk/include/um"
              "sdk/include/shared"
            ];
            libDirs = [
              "crt/lib/${archDir}"
              "sdk/lib/ucrt/${archDir}"
              "sdk/lib/um/${archDir}"
            ];
            # Use `-idirafter` (not `-isystem`) for the SDK/CRT header dirs so
            # they are searched *after* clang's builtin/resource headers. With
            # `-nostdlibinc` there are no standard system dirs, so `-idirafter`
            # dirs sit at the very end of the search order. This lets clang's
            # resource `<stddef.h>` win and `#include_next` into the UCRT one.
            # (clang-cl achieves this with `-imsvc`, but that flag is rejected
            # by the GNU `clang`/`clang++` driver this wrapper uses.)
            #
            # With plain `-isystem` the UCRT `<stddef.h>` shadows clang's resource
            # header, and since the UCRT copy lacks `max_align_t` (clang injects
            # it for the MSVC ABI), libc++ fails to build with `no type named
            # 'max_align_t' in the global namespace`.
            includeFlags = lib.concatMapStringsSep " " (d: "-idirafter ${sdk}/${d}") includeDirs;
            # The resource compiler (`windres`/`llvm-rc`) preprocesses `.rc`
            # files but, unlike the cc-wrapper, gets none of the SDK header
            # search paths, so any `#include <winver.h>` (etc.) fails. windres
            # takes include dirs via `--include-dir` (passed on to its
            # preprocessor as `-I`), so feed it the same SDK header dirs.
            windresIncludeFlags = lib.concatMapStringsSep " " (d: "--include-dir ${sdk}/${d}") includeDirs;
            libFlags = lib.concatMapStringsSep " " (d: "-L${sdk}/${d}") libDirs;
            crtFlag = lib.optionalString staticCrt "-fms-runtime-lib=static";

            # libc++ uses the MSVC ABI's `vcruntime` as its C++ runtime, and its
            # `exception.cpp` calls the MSVC `__ExceptionPtr*` EH helpers used to
            # implement `std::exception_ptr`. Those live in the MSVC *C++* runtime
            # library (`libcpmt.lib` static / `msvcprt.lib` dynamic), not in
            # vcruntime or the C runtime. Normally MSVC's STL headers pull it in
            # via `#pragma comment(lib, "libcpmt")`, but we use libc++'s headers
            # instead, so nothing references it and the link fails with undefined
            # `__ExceptionPtr*` symbols. Add it as a default library (searched
            # after the explicit inputs, so libc++'s own symbols still win and
            # only the EH-helper objects are pulled in).
            cppRuntimeLib = if staticCrt then "libcpmt" else "msvcprt";
            cppRuntimeFlag = "-Xlinker /defaultlib:${cppRuntimeLib}";

            # libc++ (and libc++abi) compile their own sources with
            # `-D_CRT_STDIO_ISO_WIDE_SPECIFIERS` (see libcxx/CMakeLists.txt
            # `cxx_add_windows_flags`), which bakes a
            # `detect_mismatch("_CRT_STDIO_ISO_WIDE_SPECIFIERS", "1")` marker
            # into every libc++ object via the UCRT headers. Application code
            # defaults to `0`, so `lld-link`'s `/failifmismatch` aborts any link
            # that mixes our libc++ with normally-compiled objects. Define it to
            # `1` for the whole set so every translation unit matches libc++.
            wideSpecifiersFlag = "-D_CRT_STDIO_ISO_WIDE_SPECIFIERS=1";

            # When targeting the MSVC ABI, the clang GNU driver defaults to
            # invoking MSVC's `link.exe`, which doesn't exist in this toolchain,
            # so any bare link fails with `posix_spawn failed: No such file or
            # directory`. CMake-driven builds escape this because they set the
            # linker explicitly, but autotools/plain-make builds (xz, bzip2, ...)
            # use the driver directly and break. Force the driver to use LLVM's
            # `lld` everywhere; for the MSVC target it resolves to `lld-link`.
            #
            # This must be a *driver* argument: in `cc-ldflags` the cc-wrapper
            # appends it in linker position, where clang forwards it verbatim to
            # the linker (and still defaults to `link.exe`). `cc-cflags` are
            # passed as driver args on every invocation (compile and link-only),
            # so clang parses it and selects the linker. During `-c` compiles it
            # is unused, but the wrapper already adds
            # `-Wno-unused-command-line-argument`.
            useLldFlag = "-fuse-ld=lld";

            # CMake manages the MSVC runtime itself: when targeting the MSVC ABI
            # it injects `-Xclang --dependent-lib=<crt>` based on its
            # `CMAKE_MSVC_RUNTIME_LIBRARY` variable, *regardless* of the
            # `-fms-runtime-lib` compiler flag above. Its default selects the
            # debug, dynamically-linked CRT (`msvcrtd`) for the configure-time
            # compiler test, but xwin only ships the *release* CRT, so the link
            # fails with `could not open 'msvcrtd.lib'`. Even when it resolves,
            # CMake's choice would fight `-fms-runtime-lib=static`.
            #
            # There is no per-package hook we can reach for the LLVM runtime
            # bootstrap (libunwind/libcxx/compiler-rt), so the cc-wrapper
            # exports a sentinel env var and a small patch to CMake's setup
            # hook (see ./patches/cmake-msvc-runtime-library.patch) turns it
            # into `-DCMAKE_MSVC_RUNTIME_LIBRARY=...`. This keeps every CMake
            # build in the set consistent with the static/dynamic choice above.
            cmakeRuntimeLib = if staticCrt then "MultiThreaded" else "MultiThreadedDLL";

            # Appended to every MSVC clang wrapper's flag files. `cc-cflags`
            # and `cc-ldflags` are consumed on every compile/link, so this
            # also fixes the toolchain bootstrap (compiler-rt, libc++, ...).
            msvcWrapperHook = ''
              printf '%s\n' "${includeFlags} ${crtFlag} ${wideSpecifiersFlag} ${useLldFlag}" >> $out/nix-support/cc-cflags
              printf '%s\n' "${libFlags} ${cppRuntimeFlag}" >> $out/nix-support/cc-ldflags
              cat <<EOF >> $out/nix-support/setup-hook
              export NIX_CMAKE_MSVC_RUNTIME_LIBRARY=${cmakeRuntimeLib}
              EOF
            '';

            # The resource compiler (`windres`, an unwrapped symlink to LLVM's
            # raw binutils binary) has no flag-file mechanism like the
            # cc-wrapper, so it never sees the SDK header search paths and any
            # `.rc` that `#include <winver.h>` (etc.) fails to preprocess.
            # Replace each `*windres` in the bintools wrapper with a tiny shell
            # shim that bakes in the SDK `--include-dir` flags before the real
            # binary's own args.
            #
            # `windres` here is a symlink chain that bottoms out at the single
            # `llvm-rc` binary, which switches between MSVC `rc.exe` mode
            # (`/D`, `/FO`, ...) and GNU `windres` mode (`-i`, `-o`,
            # `--output-format`, ...) based on its `argv[0]`. `readlink -f`
            # collapses the chain to the raw `llvm-rc` path, so we must restore
            # a `windres`-named `argv[0]` via `exec -a`; otherwise it runs in
            # `rc.exe` mode and rejects the GNU-style flags that autotools'
            # libtool passes (`Exactly one input file should be provided.`).
            windresWrapperHook = ''
              for w in $out/bin/*windres; do
                [ -e "$w" ] || continue
                real=$(readlink -f "$w")
                base=$(basename "$w")
                rm -f "$w"
                printf '#!%s\nexec -a "%s" "%s" %s "$@"\n' "${prev.runtimeShell}" "$base" "$real" "${windresIncludeFlags}" > "$w"
                chmod +x "$w"
              done
            '';

            # nixpkgs' bintools-wrapper only adds a dependency's `$out/lib` to
            # the linker search path when it looks like it holds libraries; its
            # heuristic globs `lib/lib*` (Unix `libfoo.a`/`libfoo.so` naming).
            # MSVC import/static libraries are named `z.lib`, `foo.lib` (no
            # `lib` prefix), so directories full of them are silently skipped
            # and autotools `-lz`-style links fail with `could not open
            # 'z.lib'`. Extend the glob to also accept `*.lib`.
            bintoolsLibGlobHook = ''
              if [ -e $out/nix-support/setup-hook ]; then
                sed -i 's#glob=( $1/lib/lib\* )#glob=( $1/lib/lib* $1/lib/*.lib )#' $out/nix-support/setup-hook
              fi
            '';

            stdenvMsvc = baseStdenv // {
              hostPlatform = baseStdenv.hostPlatform // {
                isStatic = true;
              };
            };
          in
          # Inject the Windows SDK search paths into every MSVC clang wrapper
          # produced in this package set (and in `pkgsBuildHost`), including
          # the LLVM toolchain bootstrap.
          (lib.optionalAttrs targetIsMsvc {
            wrapCCWith =
              args:
              prev.wrapCCWith (
                args
                // {
                  extraBuildCommands = (args.extraBuildCommands or "") + "\n" + msvcWrapperHook;
                }
              );
            wrapBintoolsWith =
              args:
              prev.wrapBintoolsWith (
                args
                // {
                  extraBuildCommands =
                    (args.extraBuildCommands or "") + "\n" + windresWrapperHook + "\n" + bintoolsLibGlobHook;
                }
              );
          })
          // (lib.optionalAttrs hostIsMsvc {
            # make this the stdenv for MSVC targets
            stdenv = stdenvMsvc;

            # nixpkgs tzdata's Windows CFLAGS assume MinGW (which has mempcpy,
            # POSIX names like open/close/read without deprecation, ssize_t, and
            # getopt). MSVC UCRT lacks all of these. Since we only need the zone
            # data + libtz.a + tzfile.h (not the zic/zdump tools), skip building
            # tools entirely to avoid the missing getopt link error.
            tzdata = prev.tzdata.overrideAttrs (old: {
              makeFlags = builtins.filter (f: !(lib.hasPrefix "CFLAGS+=-DHAVE_MEMPCPY" f)) old.makeFlags ++ [
                "CFLAGS+=-DHAVE_MEMPCPY=0"
                "CFLAGS+=-D_CRT_SECURE_NO_WARNINGS"
                "CFLAGS+=-D_CRT_NONSTDC_NO_WARNINGS"
                "CFLAGS+=-Dssize_t=__int64"
              ];
              preBuild = (old.preBuild or "") + ''
                makeFlagsArray+=("CFLAGS+=-include io.h")
              '';
              # The zic/zdump/tzselect tools need getopt which MSVC lacks.
              # We only need the zone data (produced by native zic) + libtz.a.
              # Patch the Makefile to not build or install the tools.
              postPatch = (old.postPatch or "") + ''
                sed -i '/^all:/{N; s/all:.*\n.*/all: libtz.a $(TABDATA) vanguard.zi main.zi rearguard.zi/}' Makefile
                sed -i 's/INSTALL_DATA_DEPS = zic/INSTALL_DATA_DEPS =/' Makefile
                sed -i '/cp.*tzselect.*BINDIR/d' Makefile
                sed -i '/cp.*zdump.*ZDUMPDIR/d' Makefile
                sed -i '/cp.*zic.*ZICDIR/d' Makefile
              '';
            });
          });

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
            # The MSVC ABI cross target. OpenSSL has no build configuration for
            # this ABI, so packages that hard-require OpenSSL use LibreSSL (an
            # API-compatible, CMake-buildable drop-in) there instead.
            isMsvc =
              (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
              || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));
            sslProvider = if isMsvc then final.pkg-mod-libressl else final.pkg-mod-openssl;
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
              openssl = sslProvider;
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
              openssl = sslProvider;
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
              openssl = sslProvider;
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

            pkg-mod-libpq = final.callPackage ./pkgs/libpq.nix {
              inherit static stdenv mkPackageName;
              zlib = final.pkg-mod-zlib-compat;
              openssl = sslProvider;
              tzdata = final.tzdata;
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
              openssl = sslProvider;
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

            pkg-mod-libressl = final.callPackage ./pkgs/libressl.nix {
              inherit static stdenv mkPackageName;
              # `libressl` is a thin alias that doesn't expose the `buildShared`
              # argument; the versioned attr does, which we need to force a
              # static-only build (the MSVC platform reports isStatic = false).
              libressl = final.libressl_4_2;
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
                isMinGW = (host.isWindows or false) || (host.config or "" == "x86_64-w64-mingw32");
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
                  openssl = sslProvider;
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
                # mcfgthreads is a MinGW-specific threading runtime; it is not
                # used by the MSVC/clang-cl toolchain, so restrict the override
                # to genuine MinGW hosts.
                if (final.stdenv.hostPlatform.isMinGW or false) then
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
          requireMsvcSupport ? false,
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
              && (
                if requireMsvcSupport then
                  let
                    pkg = pkgs.${name};
                  in
                  # A package opts out of the MSVC target by setting
                  # `msvcSupport = false;`. Default to building it otherwise.
                  if pkg ? msvcSupport then pkg.msvcSupport else true
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

      # mkBuildEnvMsvcCross is the MSVC-ABI counterpart of
      # `mkBuildEnvMingwCross`. It instantiates nixpkgs for the
      # `x86_64-pc-windows-msvc` cross target using the LLVM toolchain
      # (clang / clang-cl + lld-link) and layers `createMsvcOverlay` plus the
      # static package overlay on top.
      mkBuildEnvMsvcCross =
        system:
        {
          # Producing MSVC-ABI binaries requires Microsoft's Windows SDK and
          # CRT, which are unfree. nixpkgs gates these behind an explicit
          # license acknowledgement. By building this environment you accept
          # the Microsoft Software License Terms:
          #   https://visualstudio.microsoft.com/license-terms/mt644918/
          acceptMicrosoftLicense ? true,
          # Link the static MSVC runtime so the binaries are self-contained.
          staticCrt ? true,
        }:
        let
          # MSVC cross-compilation is only supported from Linux build hosts,
          # mirroring the MinGW cross environment above.
          isLinux = builtins.elem system [
            "x86_64-linux"
            "aarch64-linux"
          ];

          pkgsBase = import nixpkgs {
            inherit system;
            config.strictDeps = true;
          };

          # nixpkgs' `x86_64-pc-windows-msvc` LLVM toolchain can't bootstrap its
          # own `compiler-rt` as-is: it compiles the x87 80-bit `long double`
          # builtins, which don't exist under the MSVC ABI. That bootstrap
          # derivation is bound too early to fix with an overlay, so patch the
          # nixpkgs source itself before importing the cross package set.
          patchedNixpkgs = pkgsBase.applyPatches {
            name = "nixpkgs-msvc-compiler-rt";
            src = nixpkgs;
            patches = [
              ./patches/compiler-rt-msvc-no-80bit-builtins.patch
              ./patches/compiler-rt-msvc-atomics.patch
              ./patches/cmake-msvc-runtime-library.patch
              ./patches/libunwind-msvc-build-fixes.patch
              ./patches/libcxx-msvc-build-fixes.patch
            ];
          };

          # Cross-compiled static libraries for MSVC (x86_64-pc-windows-msvc)
          pkgsMsvcCross =
            if !isLinux then
              null
            else
              import patchedNixpkgs {
                inherit system;
                config = {
                  allowUnfree = true;
                  microsoftVisualStudioLicenseAccepted = acceptMicrosoftLicense;
                };
                crossSystem = {
                  config = "x86_64-pc-windows-msvc";
                  # Always use the LLVM toolchain: clang-cl emits the MSVC ABI
                  # and lld-link performs the final link.
                  useLLVM = true;
                };
                overlays = [
                  (createMsvcOverlay { inherit staticCrt; })
                  (mkOverlay { static = true; })
                ];
              };
        in
        {
          pkgsDefault = pkgsBase;
          pkgsMsvc = pkgsMsvcCross;
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
      lib.mkBuildEnvMsvcCross = mkBuildEnvMsvcCross;
      lib.createMsvcOverlay = createMsvcOverlay;

      packages = builtins.listToAttrs (
        map (system: {
          name = system;
          value =
            let
              buildEnv = mkBuildEnv system;
              buildEnvMingw = mkBuildEnvMingwCross system { llvm = false; };
              buildEnvMsvc = mkBuildEnvMsvcCross system { };

              pkgsStaticGlibc = buildEnv.pkgsStatic;
              pkgsStaticMusl = buildEnv.pkgsStaticMusl;
              pkgsMingwCross = buildEnvMingw.pkgsMingw;
              pkgsMsvcCross = buildEnvMsvc.pkgsMsvc;

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

              msvcAttrs = forEachPkgMod {
                pkgs = pkgsMsvcCross;
                mkName = name: "${name}-msvc-static";
                requireMsvcSupport = true;
              };
            in
            staticAttrs // muslAttrs // winAttrs // msvcAttrs;
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
