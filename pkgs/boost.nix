{
  stdenv,
  boost,
  zlib,
  zstd,
  xz,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

(boost.override {
  inherit zlib zstd xz;
  enableIcu = false;
  enablePython = false;
  # Disable Boost.Iostreams: we don't use it, and its bzip2 filter drags in
  # bzip2 (an autotools package) as a build dependency.
  extraB2Args = [ "--without-iostreams" ];
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    # we don't need/want the iostreams deps and codepage conversion features
    buildInputs = builtins.filter (
      p:
      let
        n = p.pname or p.name or "";
      in
      builtins.match ".*bzip2.*" n == null && builtins.match ".*libiconv.*" n == null
    ) old.buildInputs;
  })
