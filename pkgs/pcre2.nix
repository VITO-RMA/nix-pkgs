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
})
