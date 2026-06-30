{
  lib,
  stdenv,
  cryptopp,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

let
  isMsvc =
    (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));
in
(cryptopp.override {
  enableStatic = static;
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    # cryptopp's GNUmakefile derives the target from `$(CXX) -dumpmachine`,
    # which for this toolchain is `x86_64-pc-windows-msvc`. It only special-
    # cases MinGW/Cygwin/X86, so for the MSVC ABI it falls into the generic
    # branch and appends `-fPIC` — a flag the clang GNU driver rejects for the
    # MSVC target (`unsupported option '-fPIC'`). Teach the makefile to also
    # recognise a Windows (`windows`/`msvc`) target and skip `-fPIC` for it.
    postPatch =
      (old.postPatch or "")
      + lib.optionalString isMsvc ''
        substituteInPlace GNUmakefile \
          --replace-fail \
            'IS_MINGW := $(shell echo "$(SYSTEMX)" | $(GREP) -i -c "MinGW")' \
            'IS_MINGW := $(shell echo "$(SYSTEMX)" | $(GREP) -i -c "MinGW")
        IS_WINDOWS := $(shell echo "$(SYSTEMX)" | $(GREP) -i -c -E "windows|msvc")' \
          --replace-fail \
            'ifeq ($(IS_X86)$(IS_CYGWIN)$(IS_MINGW),000)' \
            'ifeq ($(IS_X86)$(IS_CYGWIN)$(IS_MINGW)$(IS_WINDOWS),0000)'
        # config_os.h has a deliberate hard stop for "clang pretending to be
        # MSVC" (`_MSC_VER && __clang__`) — precisely this toolchain (clang
        # targeting the MSVC ABI). Upstream notes it is OK to remove the stop
        # ("you are on your own"); disable the guard so the build proceeds.
        substituteInPlace config_os.h \
          --replace-fail \
            '#if (defined(_MSC_VER) && defined(__clang__))' \
            '#if 0 && (defined(_MSC_VER) && defined(__clang__))'
      '';
  })
