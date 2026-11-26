# src: the llama.cpp flake input. Its version is the commit date and short hash.
{ lib, llama-cpp, nodejs_latest, npmHooks, src }:

(llama-cpp.override { vulkanSupport = true; }).overrideAttrs (old: {
  version = "0-unstable-${builtins.substring 0 8 src.lastModifiedDate}";
  inherit src;

  # This service uses the API. Disable both the local UI build and the remote UI download.
  nativeBuildInputs = builtins.filter (pkg: pkg != nodejs_latest && pkg != npmHooks.npmConfigHook)
    old.nativeBuildInputs;
  npmDeps = null;
  preConfigure = null;
  cmakeFlags = builtins.filter (flag: !(lib.hasPrefix "-DLLAMA_BUILD_NUMBER" flag
    || lib.hasPrefix "-DLLAMA_BUILD_COMMIT" flag)) old.cmakeFlags ++ [
    (lib.cmakeFeature "LLAMA_BUILD_NUMBER" "0")
    (lib.cmakeFeature "LLAMA_BUILD_COMMIT" src.shortRev)
    (lib.cmakeBool "LLAMA_BUILD_UI" false)
    (lib.cmakeBool "LLAMA_USE_PREBUILT_UI" false)
  ];
})
