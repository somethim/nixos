# Update watcher. Once a day, and after an unlock (at most once in 24 hours), system-update-check
# looks for new inputs and new firmware, builds the new system (without a switch) and writes a summary.
# The update icon in the bar shows when something waits. A click starts system-update (README, section "Updates").
{ lib, pkgs, osConfig, ... }:
let
  inherit (pkgs) writeShellApplication;
  check = writeShellApplication {
    name = "system-update-check";
    runtimeInputs = with pkgs; [ coreutils findutils gnugrep gnused jq util-linux fwupd desktop-shell osConfig.nix.package ];
    text = builtins.readFile ./scripts/system-update-check;
  };
  available = writeShellApplication {
    name = "system-update-available";
    runtimeInputs = [ pkgs.coreutils ];
    text = builtins.readFile ./scripts/system-update-available;
  };
  apply = writeShellApplication {
    name = "system-update";
    runtimeInputs = with pkgs; [ coreutils git diffutils gnused gnugrep check fwupd ];
    text = builtins.readFile ./scripts/system-update;
  };
  # The build runs in the Nix daemon, so these limits cover the evaluation and the downloads.
  # The script also lowers the priority of the build and skips it on battery power.
  unit = description: args: {
    Unit.Description = description;
    Service = {
      Type = "oneshot";
      ExecStart = "${lib.getExe check}${args}";
      Nice = 15;
      IOSchedulingClass = "idle";
      CPUQuota = "200%";
      TimeoutStartSec = "2h";
    };
  };
in
{
  home.packages = [ available apply ];

  systemd.user.services = {
    system-update-check = unit "Check for system updates" "";
    # Started by the lock screen after an unlock (pkgs/desktop-shell-system-update.patch).
    system-update-unlock = unit "Check for system updates after an unlock" " --if-stale";
  };

  systemd.user.timers.system-update-check = {
    Unit.Description = "Check for system updates every day";
    Timer = {
      OnCalendar = "daily";
      Persistent = true;
      RandomizedDelaySec = "1h";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
