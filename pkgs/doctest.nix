{
  lib,
  stdenv,
  doctest,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

let
  isMsvc =
    (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));
in
(doctest.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    postPatch =
      (old.postPatch or "")
      + lib.optionalString isMsvc ''
        # doctest enables its Windows SEH fatal-condition handler for any
        # compiler defining _MSC_VER. clang targeting the MSVC ABI does that,
        # but nixpkgs' xwin CRT does not provide the debug CRT declarations used
        # by that handler (_HFILE, _CRT_ASSERT, _CRTDBG_*), so both this library
        # and downstream users fail to compile. Keep the installed header usable
        # by leaving DOCTEST_CONFIG_WINDOWS_SEH disabled for this toolchain.
        substituteInPlace doctest/doctest.h \
          --replace-fail \
            '#if DOCTEST_MSVC && !defined(DOCTEST_CONFIG_WINDOWS_SEH)' \
            '#if DOCTEST_MSVC && !defined(__clang__) && !defined(DOCTEST_CONFIG_WINDOWS_SEH)'
      '';

    cmakeFlags = old.cmakeFlags or [ ] ++ [
      "-DDOCTEST_WITH_TESTS=OFF"
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
    ];
  })
