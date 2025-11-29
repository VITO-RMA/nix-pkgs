{
  stdenv,
  libjpeg,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  fetchFromGitHub,
}:

(libjpeg.override {
  enableShared = !static;
  enableStatic = static;
}).overrideAttrs
  (old: rec {
    pname = mkPackageName old.pname static stdenv;
    version = "3.1.2";
    src = fetchFromGitHub {
      owner = "libjpeg-turbo";
      repo = "libjpeg-turbo";
      rev = version;
      hash = "sha256-tmeWLJxieV42f9ljSpKJoLER4QOYQLsLFC7jW54YZAk=";
    };

    patches = [ ./patches/libjpeg-mingw-boolean.patch ];
  })
