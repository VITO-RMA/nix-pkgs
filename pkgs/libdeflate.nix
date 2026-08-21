{
  lib,
  stdenv,
  libdeflate,
  zlib,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(libdeflate.override {
}).overrideAttrs
  (old: rec {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;
    buildInputs = [ zlib ];
    propagatedBuildInputs = buildInputs;

    env =
      (old.env or { })
      // lib.optionalAttrs ((stdenv.cc.isZig or false) && stdenv.hostPlatform.isx86) {
        # Zig disables the EVEX-512 encoding space for its baseline x86 target.
        # libdeflate enables AVX-512 per function, so permit those functions to
        # use 512-bit EVEX encodings without raising the baseline CPU level.
        NIX_CFLAGS_COMPILE = toString (lib.toList (old.env.NIX_CFLAGS_COMPILE or "") ++ [ "-mevex512" ]);
      };

    cmakeFlags = old.cmakeFlags or [ ] ++ [ (lib.cmakeBool "LIBDEFLATE_BUILD_SHARED_LIB" (!static)) ];
  })
