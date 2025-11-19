{
  lib,
  stdenv,
  onetbb,
  hwloc,
  useHwloc ? false,
  static ? stdenv.hostPlatform.isStatic,
}:

(onetbb.override { }).overrideAttrs (old: {
  doCheck = false;

  buildInputs = [ ] ++ lib.optionals useHwloc [ hwloc ];

  cmakeFlags =
    old.cmakeFlags or [ ]
    ++ [
      "-DTBB_TEST=OFF"
      "-DTBB_STRICT=OFF"
    ]
    ++ (
      if useHwloc then
        [ "-DTBB_DISABLE_HWLOC_AUTOMATIC_SEARCH=OFF" ]
      else
        [ "-DTBB_DISABLE_HWLOC_AUTOMATIC_SEARCH=ON" ]
    )
    ++ [ (lib.cmakeBool "BUILD_SHARED_LIBS" (!static)) ];
})
