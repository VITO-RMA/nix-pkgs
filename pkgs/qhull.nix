{
  lib,
  stdenv,
  qhull,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

let
  isMsvc =
    (stdenv.hostPlatform.config or "" == "x86_64-pc-windows-msvc")
    || ((stdenv.hostPlatform.isWindows or false) && (stdenv.hostPlatform.abi.name or "" == "msvc"));
in
(qhull.override {
}).overrideAttrs
  (old: {
    pname = mkPackageName old.pname static stdenv;
    doCheck = false;

    patches = (old.patches or [ ]) ++ [
      ./patches/qhull-noapp.patch
      ./patches/qhull-fix-qhullcpp-cpp20-support.patch
    ];

    # qhull's CMakeLists.txt has `project()` before `cmake_minimum_required()`.
    # This means CMP0091 (MSVC runtime library abstraction) isn't active when
    # the compiler test runs during project(), causing it to link with the debug
    # DLL CRT (msvcrtd.lib) which the release-only Windows SDK doesn't ship.
    # Swap the order so policies are set before the compiler test.
    postPatch =
      (old.postPatch or "")
      + lib.optionalString isMsvc ''
        substituteInPlace CMakeLists.txt \
          --replace-fail \
            $'project(qhull)\ncmake_minimum_required(VERSION 3.5...4.0)' \
            $'cmake_minimum_required(VERSION 3.5...4.0)\nproject(qhull)'
      '';

    cmakeFlags = (old.cmakeFlags or [ ]) ++ [
      (lib.cmakeBool "BUILD_SHARED_LIBS" (!static))
      (lib.cmakeBool "BUILD_APPLICATIONS" false)
    ];

    # In static builds:
    # - Remove the qhull_r.pc file which references -lqhull_r that doesn't exist
    #   (only libqhullstatic_r.a is built), so consumers fall back to find_library.
    # - Create a Qhull::qhull_r interface target that aliases to Qhull::qhullstatic_r,
    #   so consumers expecting the shared target transparently get the static one.
    postInstall =
      (old.postInstall or "")
      + lib.optionalString static ''
            rm -f $out/lib/pkgconfig/qhull_r.pc
            cat >> $out/lib/cmake/Qhull/QhullTargets.cmake <<'EOF'
            if(NOT TARGET Qhull::qhull_r)
              add_library(Qhull::qhull_r IMPORTED INTERFACE)
              set_target_properties(Qhull::qhull_r PROPERTIES INTERFACE_LINK_LIBRARIES Qhull::qhullstatic_r)
            endif()
        EOF
      '';

    meta = old.meta // {
      platforms = lib.platforms.all;
    };
  })
