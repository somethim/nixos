# Lid Awake Indicators

The upstream indicators (without passwordless sudo and remote session), plus Lid Awake:

- **Lid Awake:** a toggle that keeps a laptop running when its lid closes and turns the internal panel off while the lid is shut. Useful for downloads, builds, music, or a remote session with the laptop closed.

It is a drop-in replacement for the built-in `omarchy.indicators` widget. It includes the same indicators (screen recording, reminder, Do Not Disturb, stay awake; night light is left to a separate plugin) and adds Lid Awake to the same row. They share the same look, spacing, and hover reveal.

- **Lid Awake glyph (󰒳):** bright while lid awake is on. While it's off, it reveals dimmed with the other inactive indicators when you hover the bar's center section. Click it to toggle.
- **Desktops:** the Lid Awake indicator stays hidden when there's no lid.

## Install

```bash
omarchy plugin add https://github.com/somethim/omarchy-lid-awake.git --enable
```

Enabling it takes the place of `omarchy.indicators` in your bar and keeps that entry's settings, such as the `items` you chose. Removing or disabling it puts the built-in indicators back. This is the same mechanism the upstream desktop uses for `omarchy plugin clone`.

If you picked specific indicators with `items`, add `"LidAwake"` to the list:

```json
{ "id": "somethim.lid-awake", "items": ["ScreenRecording", "Reminder", "Dnd", "StayAwake", "LidAwake"] }
```

With no `items`, every indicator is shown, Lid Awake included. If the widget fails to load right after installing, run `omarchy restart shell`.

### Optional keybinding

Add this to `~/.config/hypr/bindings.lua`:

```lua
o.bind("SUPER + CTRL + ALT + L", "Toggle lid awake", "$HOME/.config/omarchy/plugins/somethim.lid-awake/bin/lid-awake toggle")
```

## How it works

**Lid awake:** `bin/lid-awake on` starts a transient systemd user unit, `omarchy-lid-awake.service`. The unit holds a `handle-lid-switch` inhibitor, so logind does not suspend on lid close. Inside it, a small watcher polls the lid once a second and switches the internal panel (eDP/LVDS/DSI) off with `hyprctl` while the lid is shut. When an external display is connected, the upstream clamshell mode already handles the panel, so the watcher leaves it alone. The state is the unit itself: it survives shell restarts and ends when you log out. The upstream lid handling still runs, so closing the lid still locks the screen. Power button, idle suspend, and low-battery handling are unaffected.

**The other indicators:** the built-in widget reads Do Not Disturb and stay awake from shell services that third-party plugins cannot reach. This plugin reads them with `bin/indicator-state` instead, every two seconds, through `omarchy-shell` and `omarchy toggle`. Clicks go through the same commands. The other indicators are unchanged copies of the upstream ones.

Command line: `bin/lid-awake [toggle|on|off|status]` (`status` prints `on`, `off`, or `unavailable`) and `bin/indicator-state [status|dnd|idle|lid]`.

## Dependencies

All of these ship with the upstream desktop 4: `systemd` (`systemd-run`, `systemd-inhibit`, `systemctl --user`), `hyprctl`, `jq`, `omarchy-shell`, `omarchy toggle`, and the upstream `omarchy-hw-laptop`, `omarchy-hw-laptop-closed`, `omarchy-hw-external-monitors`, and `omarchy-hyprland-monitor-laptop` helpers. No root access is needed. The copied indicators follow the upstream ones at the time of the plugin's version.

## Uninstall

```bash
~/.config/omarchy/plugins/somethim.lid-awake/bin/lid-awake off
omarchy plugin remove somethim.lid-awake
```

The built-in indicators return to the same place in the bar. Remove the optional keybinding if you added it.

## License

MIT. The indicator files are adapted from [Omarchy](https://github.com/basecamp/omarchy) (MIT).
