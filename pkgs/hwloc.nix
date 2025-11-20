{
  lib,
  stdenv,
  fetchFromGitHub,
  autoreconfHook,
  pkg-config,
  numactl,
  static ? stdenv.hostPlatform.isStatic,
  mkPackageName,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = mkPackageName "hwloc" static stdenv;

  version = "2.12.2";

  src = fetchFromGitHub {
    owner = "open-mpi";
    repo = "hwloc";
    tag = "hwloc-${finalAttrs.version}";
    hash = "sha256-xLrhffz6pDSjkvAsPWSM3m8OxMV14/6kUgWOlI2u6go=";
  };

  configureFlags = [
    "--localstatedir=/var"
    "--enable-netloc"
    "--disable-libxml2"
    "--disable-opencl"
    "--disable-cairo"
    "--disable-cuda"
    "--disable-libudev"
    "--disable-levelzero"
    "--disable-nvml"
    "--disable-rsmi"
    "--disable-pci"
  ]
  ++ lib.optionals static [
    "--enable-static"
    "--disable-shared"
  ];

  nativeBuildInputs = [
    autoreconfHook
    pkg-config
  ];

  buildInputs = [
  ];

  enableParallelBuilding = true;

  postInstall = lib.optionalString stdenv.hostPlatform.isLinux ''
    if [ -d "${numactl}/lib64" ]; then
      numalibdir="${numactl}/lib64"
    else
      numalibdir="${numactl}/lib"
      test -d "$numalibdir"
    fi

    sed -i "$lib/lib/libhwloc.la" \
      -e "s|-lnuma|-L$numalibdir -lnuma|g"
  '';

  # Checks disabled because they're impure (hardware dependent) and
  # fail on some build machines.
  doCheck = false;

  outputs = [
    "out"
    "lib"
    "dev"
    "doc"
    "man"
  ];

  meta = {
    description = "Portable abstraction of hierarchical architectures for high-performance computing";
    longDescription = ''
      hwloc provides a portable abstraction (across OS,
      versions, architectures, ...) of the hierarchical topology of
      modern architectures, including NUMA memory nodes, sockets,
      shared caches, cores and simultaneous multithreading.  It also
      gathers various attributes such as cache and memory
      information.  It primarily aims at helping high-performance
      computing applications with gathering information about the
      hardware so as to exploit it accordingly and efficiently.

      hwloc may display the topology in multiple convenient
      formats.  It also offers a powerful programming interface to
      gather information about the hardware, bind processes, and much
      more.
    '';
    # https://www.open-mpi.org/projects/hwloc/license.php
    license = lib.licenses.bsd3;
    homepage = "https://www.open-mpi.org/projects/hwloc/";
    platforms = lib.platforms.all;
  };
})
