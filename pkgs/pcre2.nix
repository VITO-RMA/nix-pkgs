{
  lib,
  stdenv,
  pcre2,
  static ? stdenv.hostPlatform.isStatic,
}:

pcre2.overrideAttrs (old: {
  doCheck = false;

  configureFlags =
    (old.configureFlags or [ ])
    ++ lib.optionals static [
      "--enable-static"
      "--disable-shared"
    ];
})
