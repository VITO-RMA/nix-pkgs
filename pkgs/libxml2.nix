{
  lib,
  static ? stdenv.hostPlatform.isStatic,
  stdenv,
  libxml2,
  zlib,
  libiconv,
  cmake,
  mkPackageName,
  ...
}:

let
  isMsvc =
    (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));
in
(libxml2.override {
  enableStatic = static;
  enableShared = !static;
  zlibSupport = true;
  inherit libiconv;
  inherit zlib;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    # Always build libxml2 with its bundled CMake build system rather than
    # autotools. CMake handles every target uniformly, and in particular it
    # supports Windows natively (Win32 threads, `LoadLibrary` modules). The
    # autotools configure only recognises the mingw/cygwin Windows triples, so
    # for the clang GNU-driver `*-windows-msvc` triple it misdetects the
    # platform and aborts demanding a POSIX `dlopen`/`libpthread`.
    nativeBuildInputs =
      builtins.filter (p: !(lib.hasInfix "autoreconf" (p.name or ""))) (old.nativeBuildInputs or [ ])
      ++ [ cmake ];

    # The CMake build is configured purely through `cmakeFlags`; the autotools
    # `configureFlags` would otherwise be forwarded to `cmake` and rejected.
    configureFlags = [ ];

    # libiconv is propagated by the base derivation for darwin/mingw/cygwin, but
    # not for MSVC. Add it explicitly so CMake's FindIconv succeeds.
    buildInputs = (old.buildInputs or [ ]) ++ lib.optional isMsvc libiconv;

    cmakeFlags = [
      # Use relative install dirs so the generated .pc file doesn't end up with
      # broken `${prefix}//nix/store/...` absolute paths (nixpkgs #144170).
      "-DCMAKE_INSTALL_LIBDIR=lib"
      "-DCMAKE_INSTALL_INCLUDEDIR=include"
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
      (lib.cmakeBool "LIBXML2_WITH_ZLIB" true)
      (lib.cmakeBool "LIBXML2_WITH_THREADS" true)
      (lib.cmakeBool "LIBXML2_WITH_PYTHON" false)
      (lib.cmakeBool "LIBXML2_WITH_TESTS" false)
      (lib.cmakeBool "LIBXML2_WITH_PROGRAMS" false)
      (lib.cmakeBool "LIBXML2_WITH_ICU" false)
      (lib.cmakeBool "LIBXML2_WITH_HTTP" false)
      (lib.cmakeBool "LIBXML2_WITH_ICONV" true)
      # Static archives can't dlopen/LoadLibrary plugins meaningfully, so drop
      # the dynamic module loader for static builds.
      (lib.cmakeBool "LIBXML2_WITH_MODULES" (!static))
    ];

    # Multi-output splits create reference cycles (cmake config in dev points
    # to out, static lib in out embeds a hash matching dev from include paths).
    # Use a single output to side-step the cycle entirely.
    outputs = [ "out" ];
    # With a single output, redirect all multi-output assignments to `out`.
    outputDev = "out";
    outputBin = "out";
    outputMan = "out";
    outputDoc = "out";
    outputInfo = "out";

    # The autotools-specific fixup (`xml2-config`, `xml2Conf.sh`) doesn't apply
    # to the CMake install layout (which ships `libxml2-config.cmake`).
    postFixup = "";
  })
