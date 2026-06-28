{
  lib,
  stdenv,
  fetchurl,
  cmake,
  ninja,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
  qtbase,
  libxkbcommon ? null,
}:

stdenv.mkDerivation rec {
  pname = mkPackageName "qwt" static stdenv;
  version = "6.3.0";

  src = fetchurl {
    url = "mirror://sourceforge/qwt/qwt-${version}.tar.bz2";
    hash = "sha256-3LCFiWwoquxVGMvAjA7itOYK2nrJKdgmOfYYmFGmEpo=";
  };

  dontWrapQtApps = true;

  nativeBuildInputs = [
    cmake
    ninja
  ];

  buildInputs = [ qtbase ];

  # Static Qt6Gui cmake config requires its transitive deps at configure time.
  propagatedBuildInputs =
    lib.optionals (static && stdenv.hostPlatform.isLinux && !stdenv.hostPlatform.isMusl)
      [
        libxkbcommon
      ];

  postPatch = ''
    cp ${./patches/qwt-cmake.txt} CMakeLists.txt
    # AUTOMOC generates moc files externally; remove the inline includes.
    sed -i 's|^#include "moc_.*|//\0|' src/*.cpp
    # Qt6 metatype system needs full type definitions, not forward declarations.
    sed -i src/qwt_picker.h \
      -e 's|^class QPen;|#include <QPen>|' \
      -e 's|^class QFont;|#include <QFont>|'
    sed -i src/qwt_plot_canvas.h \
      -e 's|^class QPainterPath;|#include <QPainterPath>|'
    sed -i src/qwt_abstract_legend.h \
      -e '/^class QwtLegendData;/d' \
      -e '/^template.*QList;/d' \
      -e 's|#include "qwt_global.h"|#include "qwt_global.h"\n#include "qwt_legend_data.h"|'
    sed -i src/qwt_plot.h \
      -e '/^class QwtLegendData;/d' \
      -e 's|#include "qwt_text.h"|#include "qwt_text.h"\n#include "qwt_legend_data.h"|'
  '';

  cmakeFlags = [
    "-DQWT_BUILD_EXAMPLES=OFF"
    (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
  ];

  meta = with lib; {
    description = "Qt Widgets for Technical Applications";
    homepage = "https://qwt.sourceforge.io/";
    license = [
      licenses.lgpl21Only
      licenses.qwtException
    ];
    platforms = platforms.all;
  };
}
