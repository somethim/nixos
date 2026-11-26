{ lib, stdenv, fetchFromGitHub, writeText, makeWrapper, gawk, coreutils, gnugrep, cmake, ninja, pkg-config, python3, boost, protobuf
, abseil-cpp, libdrm, curl, openssl, ncurses, util-linux, elfutils, rapidjson
, opencl-headers, ocl-icd, systemd, libffi, zlib, libsystemtap }:

# AMD XRT (Xilinx Runtime) for the XDNA NPU only, with the amdxdna shim plugin.
# Both come from the amd/xdna-driver tag: the tag pins the XRT submodule that fits the shim.
# Same version as the Arch Linux packages "xrt" and "xrt-plugin-amdxdna" that FastFlowLM documents.
let
  version = "2.21.75";
  patch = lib.last (lib.splitVersion version);
in
stdenv.mkDerivation (finalAttrs: {
  pname = "xrt";
  inherit version;

  src = fetchFromGitHub {
    owner = "amd";
    repo = "xdna-driver";
    tag = finalAttrs.version;
    fetchSubmodules = true;
    hash = "sha256-bBiI42bwap6O59MQdIylX7uz+fLUF75RTyNWTJfAFds=";
  };

  # The XRT CMake files read /etc/os-release to find the Linux distribution. The sandbox has no such file.
  postPatch = ''
    substituteInPlace xrt/src/CMake/icd.cmake \
      --replace-fail '"/etc/OpenCL/vendors"' '"etc/OpenCL/vendors"'
    substituteInPlace xrt/src/CMake/nativeLnx.cmake CMake/pkg.cmake \
      --replace-fail /etc/os-release ${writeText "os-release" ''
        ID=nixos
        VERSION_ID="26.05"
      ''}
  '';

  nativeBuildInputs = [ cmake ninja pkg-config python3 makeWrapper ];
  buildInputs = [
    boost protobuf abseil-cpp libdrm curl openssl ncurses util-linux elfutils rapidjson
    opencl-headers ocl-icd systemd libffi zlib libsystemtap
  ];

  # XRT_UPSTREAM_DEBIAN is the switch for distribution builds: no git, no packaging.
  # The XRT build calls CMake in its own way, so the CMake hook stays off.
  dontUseCmakeConfigure = true;
  dontUseNinjaBuild = true;
  dontUseNinjaInstall = true;
  dontUseNinjaCheck = true;

  configurePhase = ''
    runHook preConfigure
    cmake -G Ninja -S xrt/src -B build-xrt \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=$out \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DXRT_NPU=1 \
      -DXRT_ENABLE_WERROR=0 \
      -DXRT_UPSTREAM_DEBIAN=1 \
      -DXRT_BUILD_NUMBER=${patch}

    # The amdxdna plugin (shim). SKIP_KMOD leaves out the kernel driver and the firmware:
    # the kernel has the driver and linux-firmware has the firmware. The packaging code of
    # the project wants two data directories. They stay empty.
    mkdir -p amdxdna_bins/download_raw/xbutil_validate/bins amdxdna_bins/vtd_archives
    XRT_PLUGIN_VERSION_PATCH=${patch} cmake -G Ninja -S . -B build-shim \
      -DCMAKE_BUILD_TYPE=Release \
      -DCMAKE_INSTALL_PREFIX=$out \
      -DCMAKE_INSTALL_LIBDIR=lib \
      -DCMAKE_INSTALL_RPATH=$out/lib \
      -DCMAKE_CXX_STANDARD=17 \
      -DSKIP_KMOD=1 \
      -DXRT_NPU=1 \
      -DXRT_ENABLE_WERROR=0 \
      -DXRT_UPSTREAM_DEBIAN=1 \
      -DXRT_BUILD_NUMBER=${patch}
    runHook postConfigure
  '';

  buildPhase = ''
    runHook preBuild
    cmake --build build-xrt
    cmake --build build-shim --target xrt_driver_xdna
    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall
    cmake --install build-xrt
    cmake --install build-shim --component amdxdna
    runHook postInstall
  '';

  # The scripts bin/xrt-smi and bin/xclbinutil source setup.sh. It calls awk, uname and grep.
  postFixup = ''
    for tool in xrt-smi xclbinutil; do
      wrapProgram $out/bin/$tool --prefix PATH : ${lib.makeBinPath [ gawk coreutils gnugrep ]}
    done
  '';

  # Build-level test: the plugin is next to the core library (XRT looks for it there)
  # and the tool starts. The sandbox has no NPU, so nothing more can run here.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    test -e $out/lib/libxrt_driver_xdna.so.2
    $out/bin/xrt-smi --version | grep -q ${finalAttrs.version}
    runHook postInstallCheck
  '';

  meta = {
    description = "AMD XRT runtime for the XDNA NPU, with the amdxdna plugin";
    homepage = "https://github.com/Xilinx/XRT";
    license = with lib.licenses; [ asl20 gpl2Only ];
    platforms = [ "x86_64-linux" ];
  };
})
