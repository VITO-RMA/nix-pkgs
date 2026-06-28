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
  # __declspec(dllimport) decorations on Windows.  Patching the header
  # directly (like vcpkg does) makes this work for all consumers,
  # not only those using pkg-config.
  postFixup =
    (old.postFixup or "")
    + lib.optionalString static ''
      for pc in $dev/lib/pkgconfig/*.pc; do
        substituteInPlace "$pc" \
          --replace "Cflags:" "Cflags: -DPCRE2_STATIC"
      done
      substituteInPlace $dev/include/pcre2.h \
        --replace "defined(PCRE2_STATIC)" "1"
    ''
    + lib.optionalString (!static) ''
      substituteInPlace $dev/include/pcre2.h \
        --replace "defined(PCRE2_STATIC)" "0"
    '';
})
