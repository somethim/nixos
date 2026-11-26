{ config, lib, pkgs, inputs, ... }:

let
  llama = pkgs.callPackage ../pkgs/llama-cpp-vulkan.nix { src = inputs.llama-cpp; };
  models = "${config.xdg.dataHome}/models";
  # NPU path: FastFlowLM on the XDNA2 NPU. The xrt package includes the amdxdna plugin.
  xrt = pkgs.callPackage ../pkgs/xrt.nix { };
  flm = pkgs.callPackage ../pkgs/fastflowlm.nix { inherit xrt; };
  npuModels = "${config.xdg.dataHome}/flm";
in
{
  home.packages = [ llama flm xrt ];

  # `flm pull` and the service use the same model directory.
  home.sessionVariables.FLM_MODEL_PATH = npuModels;

  systemd.user.services.llama-server = {
    Unit = {
      Description = "Local llama.cpp model server";
      ConditionPathIsDirectory = models;
    };
    Service = {
      ExecStart = ''${lib.getExe' llama "llama-server"} --host 127.0.0.1 --port 8080 --models-dir "${models}" --models-max 1'';
    };
  };

  # The API is on 127.0.0.1:52625, the port that home/config/opencode/npu.json uses.
  # The model files must be there before the first start: `flm pull qwen3.5:9b` (README 4.5).
  systemd.user.services.flm-server = {
    Unit.Description = "Local FastFlowLM model server on the NPU";
    Service = {
      Environment = [ "FLM_MODEL_PATH=${npuModels}" "FLM_SERVE_PORT=52625" ];
      ExecStartPre = "${pkgs.coreutils}/bin/mkdir -p ${npuModels}";
      ExecStart = "${lib.getExe flm} serve qwen3.5:9b";
      LimitMEMLOCK = "infinity"; # the NPU driver pins the model memory
    };
  };
}
