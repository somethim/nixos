# AMD XDNA2 NPU (Ryzen AI): limits that FastFlowLM needs.
# The driver (amdxdna) is part of the Linux kernel and loads by itself when it finds the NPU.
# The firmware comes from linux-firmware (hardware.enableRedistributableFirmware in modules/system.nix).
# The device /dev/accel/accel0 is open to all users: the udev rules of systemd set mode 0666.
{ user, ... }:
{
  # The NPU driver pins the memory of the model. A low memlock limit stops it.
  # `flm validate` must show "Memlock Limit: infinity".
  security.pam.loginLimits = [
    { domain = user; type = "-"; item = "memlock"; value = "unlimited"; }
  ];
}
