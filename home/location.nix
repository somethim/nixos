# Weather location from GeoClue. Every 30 minutes the unit asks GeoClue for the position and
# writes it to the weather state file of the shell, so the weather panel shows exact data.
# A location that the user sets by hand (no "source":"geoclue" in the file) is never changed.
{ lib, pkgs, osConfig, ... }:
let
  whereAmI = "${osConfig.services.geoclue2.package}/libexec/geoclue-2.0/demos/where-am-i";
  update = pkgs.writeShellApplication {
    name = "weather-location-update";
    runtimeInputs = with pkgs; [ coreutils gawk jq ];
    text = builtins.readFile ./scripts/weather-location-update;
  };
in
{
  systemd.user.services.weather-location = {
    Unit.Description = "Weather location from GeoClue";
    Service = {
      Type = "oneshot";
      Environment = [ "WHERE_AM_I=${whereAmI}" ];
      ExecStart = lib.getExe update;
      TimeoutStartSec = 60;
    };
  };

  systemd.user.timers.weather-location = {
    Unit.Description = "Weather location from GeoClue, every 30 minutes";
    Timer = {
      OnStartupSec = "1min";
      OnUnitActiveSec = "30min";
    };
    Install.WantedBy = [ "timers.target" ];
  };
}
