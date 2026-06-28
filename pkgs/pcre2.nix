{
  lib,
  stdenv,
  pcre2,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

pcre2.overrideAttrs (old: {
  pname = mkPackageName old.pname static stdenv;
  doCheck = false;

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];

  # When built statically, consumers must define PCRE2_STATIC to avoid
  # __declspec(dllimport) decorations on Windows.
  postFixup =
    (old.postFixup or "")
    + lib.optionalString static ''
      for pc in $out/lib/pkgconfig/*.pc; do
        sed -i "s|^Cflags:|Cflags: -DPCRE2_STATIC|" "$pc"
      done
    '';
})
