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
    version = "3.1.4.1";
    src = fetchFromGitHub {
      owner = "libjpeg-turbo";
      repo = "libjpeg-turbo";
      rev = version;
      hash = "sha256-jBajigX4/j4jG11prTPeGkTVRrRzheFL/LxgnPufzb4=";
    };

    patches = [ ./patches/libjpeg-mingw-boolean.patch ];
  })
