# Robotics + embedded learning stack (see ~/Learning/ROADMAP.md, WORKBENCH.md),
# and the built-in smart card reader.
{ pkgs, user, ... }:
{
  environment.systemPackages = with pkgs; [
    # Embedded Rust on RPi Pico / STM32 (no_std, embedded-hal):
    # targets come from rustup (thumbv6m-none-eabi, thumbv7em-none-eabihf).
    probe-rs-tools flip-link elf2uf2-rs picotool
    gcc-arm-embedded openocd stlink        # C toolchain, arm-none-eabi-gdb, debug probes
    # Talking to boards: serial terminals, plotting, logic analyzer (SPI/I2C decode)
    tio picocom serial-studio pulseview sigrok-cli
    # Drones: ground control and flight-controller config
    qgroundcontrol betaflight-configurator
    # PX4 SITL + Gazebo + ROS 2 Jazzy run in an Ubuntu 24.04 container
    # (`distrobox create -i ubuntu:24.04 -n ros`), where they are supported.
    distrobox
    # CAD and electronics
    kicad freecad
    # Smart card reader: PIV / OpenPGP cards (keys that stay on the card)
    opensc pcsc-tools
  ];

  # Control / estimation maths (Underactuated Robotics, Kalman filters), in the system Python.
  python.packages = [ "numpy" "scipy" "matplotlib" "sympy" "jupyterlab" "control" "pyserial" ];

  # Debug probes, Pico boot mode and serial adapters usable without sudo.
  services.udev.packages = with pkgs; [ probe-rs-tools openocd stlink picotool ];
  users.users.${user}.extraGroups = [ "dialout" "plugdev" ];
  users.groups.plugdev = { };

  # Smart card daemon for the built-in reader.
  services.pcscd = { enable = true; plugins = [ pkgs.ccid ]; };
}
