{ lib, stdenv, fetchFromGitHub, fetchurl, cmake, ninja, pkg-config, nasm, cargo, rustc
, rustPlatform, autoPatchelfHook, boost, curl, libedit, libdrm, util-linux
, oniguruma, xrt }:

let
  # CMake downloads these codecs while it configures. The sandbox has no network,
  # so each tarball is a fixed input and the CMake files point to it.
  tarballs = {
    libjpeg_turbo = fetchurl {
      url = "https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/3.2.0/libjpeg-turbo-3.2.0.tar.gz";
      sha256 = "6f30092cef9fb839779646608f4ee14ae3cbac989c47fa05e841b0841f09878e";
    };
    libwebp = fetchurl {
      url = "https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-1.6.0.tar.gz";
      sha256 = "e4ab7009bf0629fd11982d4c2aa83964cf244cffba7347ecd39019a9e38c4564";
    };
    opus = fetchurl {
      url = "https://downloads.xiph.org/releases/opus/opus-1.6.1.tar.gz";
      sha256 = "6ffcb593207be92584df15b32466ed64bbec99109f007c82205f0194572411a1";
    };
    ogg = fetchurl {
      url = "https://github.com/xiph/ogg/releases/download/v1.3.6/libogg-1.3.6.tar.gz";
      sha256 = "83e6704730683d004d20e21b8f7f55dcb3383cdf84c0daedf30bde175f774638";
    };
    vorbis = fetchurl {
      url = "https://github.com/xiph/vorbis/releases/download/v1.3.7/libvorbis-1.3.7.tar.gz";
      sha256 = "0e982409a9c3fc82ee06e08205b1355e5c6aa4c36bca58146ef399621b0ce5ab";
    };
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "fastflowlm";
  version = "1.0.13";

  src = fetchFromGitHub {
    owner = "FastFlowLM";
    repo = "FastFlowLM";
    tag = "v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-4HFqZrHGo1Kpeyku6LRqWrDnrCb31fbhmBDVGRkdxDg=";
  };

  # The tokenizer library has a Rust part. The upstream tree has no Cargo.lock,
  # so the repository keeps one. cargoSetupHook gives Cargo the vendored crates.
  cargoRoot = "third_party/tokenizers-cpp/rust";
  cargoDeps = rustPlatform.importCargoLock { lockFile = ./fastflowlm-tokenizers-Cargo.lock; };

  postPatch = ''
    cp ${./fastflowlm-tokenizers-Cargo.lock} third_party/tokenizers-cpp/rust/Cargo.lock

    substituteInPlace src/cmake/FlmImageCodecs.cmake \
      --replace-fail 'URL https://github.com/libjpeg-turbo/libjpeg-turbo/releases/download/''${FLM_LIBJPEG_TURBO_VERSION}/libjpeg-turbo-''${FLM_LIBJPEG_TURBO_VERSION}.tar.gz' 'URL ${tarballs.libjpeg_turbo}' \
      --replace-fail 'URL https://storage.googleapis.com/downloads.webmproject.org/releases/webp/libwebp-''${FLM_LIBWEBP_VERSION}.tar.gz' 'URL ${tarballs.libwebp}'
    substituteInPlace src/cmake/FlmAudioCodecs.cmake \
      --replace-fail 'URL ''${urls}' 'URL ''${FLM_TARBALL_''${name}}'
  '';

  nativeBuildInputs = [
    cmake ninja pkg-config nasm cargo rustc rustPlatform.cargoSetupHook autoPatchelfHook
  ];
  buildInputs = [ boost curl libedit libdrm util-linux oniguruma xrt stdenv.cc.cc.lib ];

  # The CMake project is in src/. The preset linux-default gives the build type and layout.
  cmakeDir = "../src";
  cmakeFlags = [
    (lib.cmakeFeature "CMAKE_BUILD_TYPE" "Release")
    (lib.cmakeFeature "FLM_VERSION" finalAttrs.version)
    (lib.cmakeFeature "NPU_VERSION" "32.0.203.304")
    (lib.cmakeFeature "CMAKE_XCLBIN_PREFIX" "${placeholder "out"}/share/flm")
    # The Rust tokenizer uses the oniguruma library of the system (RUSTONIG_SYSTEM_LIBONIG in the Rust hook).
    # The static Rust library leaves its symbols open, so the link line needs the library.
    (lib.cmakeFeature "CMAKE_CXX_STANDARD_LIBRARIES" "-lonig")
    (lib.cmakeFeature "FLM_TARBALL_opus" "${tarballs.opus}")
    (lib.cmakeFeature "FLM_TARBALL_ogg" "${tarballs.ogg}")
    (lib.cmakeFeature "FLM_TARBALL_vorbis" "${tarballs.vorbis}")
  ];

  # Build-level test: the CLI starts and all prebuilt engine libraries resolve. The sandbox has no NPU.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    $out/bin/flm version | grep -q ${finalAttrs.version}
    runHook postInstallCheck
  '';

  meta = {
    description = "Run large language models on AMD Ryzen AI NPUs";
    homepage = "https://github.com/FastFlowLM/FastFlowLM";
    # The runtime code is MIT. The NPU kernels (xclbin files) and the prebuilt engine
    # libraries are not open source. Their licence allows any use and unmodified redistribution.
    license = with lib.licenses; [ mit unfreeRedistributable ];
    mainProgram = "flm";
    platforms = [ "x86_64-linux" ];
  };
})
