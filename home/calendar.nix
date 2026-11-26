# Google calendars in the bar clock panel, read-only.
# Google gives each calendar a "Secret address in iCal format". vdirsyncer fetches that
# address into ~/.local/share/calendars every 15 minutes, and khal reads the local copy.
# The addresses are secrets: they stay in the GNOME Keyring and are read with `secret-tool` at
# each sync. They are not in this repository and not in the Nix store (README: Calendar events).
{ lib, pkgs, ... }:
let
  # Calendar names (not secret). Store the address of each name in the keyring first (README 3.3).
  # Example: [ "personal" ]
  calendars = [ ];
in
{
  accounts.calendar = {
    basePath = ".local/share/calendars"; # relative to the home directory
    accounts = lib.genAttrs calendars (name: {
      local = { type = "filesystem"; fileExt = ".ics"; };
      remote.type = "http"; # no url here: it comes from urlCommand
      vdirsyncer = {
        enable = true;
        # The address is printed at run time and kept in memory only.
        urlCommand = [ "${pkgs.libsecret}/bin/secret-tool" "lookup" "service" "vdirsyncer" "calendar" name ];
        conflictResolution = "remote wins";
      };
      khal.enable = true;
    });
  };

  programs.vdirsyncer.enable = true;
  services.vdirsyncer = {
    enable = calendars != [ ]; # no timer until a calendar is added
    frequency = "*:0/15"; # every 15 minutes
    # Only critical messages reach the journal. For a server error (for example HTTP 5xx) vdirsyncer
    # logs the exception at error level, and that text holds the full request URL, which is the
    # secret address. A failed sync still fails the unit (see `systemctl --user status vdirsyncer`);
    # run `vdirsyncer -v DEBUG sync` by hand to see the cause, but never share that output.
    verbosity = "CRITICAL";
  };

  # khal only reads the local copy. The panel parses these formats (pkgs/desktop-shell-calendar-events.patch).
  programs.khal = {
    enable = true;
    locale = {
      dateformat = "%Y-%m-%d";
      timeformat = "%H:%M";
      datetimeformat = "%Y-%m-%d %H:%M";
      longdateformat = "%Y-%m-%d";
      longdatetimeformat = "%Y-%m-%d %H:%M";
    };
  };
}
