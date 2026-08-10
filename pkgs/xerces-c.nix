{
  lib,
  stdenv,
  xercesc,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  icu,
}:

xercesc.overrideAttrs (old: rec {
  pname = mkPackageName "xerces-c" static stdenv;

  buildInputs = [ icu ];
  propagatedBuildInputs = buildInputs;

  doCheck = false;

  # The upstream build unconditionally builds the "tests" and "samples"
  # subdirectories, producing ~16 demo CLI tools (SAXCount, DOMCount, etc).
  # For static builds each one statically links the full xerces-c/ICU/libc
  # closure, ballooning the closure to hundreds of MB even though nothing
  # here needs these tools. Drop them from the top-level SUBDIRS so they're
  # never built or installed.
  postPatch = (old.postPatch or "") + ''
    sed -i 's/^SUBDIRS = doc src tests samples/SUBDIRS = doc src/' Makefile.in Makefile.am
  '';

  # GCC 15 on MinGW treats duplicate explicit template instantiations as
  # errors (XMLByte=unsigned char clashes with an existing instantiation).
  env =
    (old.env or { })
    // lib.optionalAttrs stdenv.hostPlatform.isMinGW {
      NIX_CFLAGS_COMPILE = toString (lib.toList (old.env.NIX_CFLAGS_COMPILE or "") ++ [ "-fpermissive" ]);
    };

  # Drop curl; pick the platform-native net accessor instead.
  configureFlags =
    let
      netAccessor =
        if stdenv.hostPlatform.isMinGW then
          "winsock"
        else if stdenv.hostPlatform.isDarwin then
          "cfurl"
        else
          "socket";
    in
    [
      "--enable-netaccessor-${netAccessor}"
      "--enable-transcoder-icu"
    ]
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];

  # Install a cmake package config so that consumers (like pcraster) pick
  # up transitive link dependencies automatically for static builds.
  postInstall = (old.postInstall or "") + ''
    mkdir -p $out/lib/cmake/XercesC
    cp ${./patches/xerces-c-config.cmake} $out/lib/cmake/XercesC/XercesCConfig.cmake
  '';

  meta = old.meta // {
    platforms = lib.platforms.all;
  };
})
