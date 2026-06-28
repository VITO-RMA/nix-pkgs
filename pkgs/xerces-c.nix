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
