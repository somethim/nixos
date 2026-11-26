-- Extra autostart processes.
-- o.launch_on_start("my-service")

-- NixOS: Thunderbird has no tray on Linux (Mozilla bug 1627479), so Thunderbird and
-- Zoho Mail open silently on a hidden "mail" workspace. Super+Shift+E shows and hides it
-- (bindings.lua).
-- Other tray apps (Steam, Discord, Heroic, ZapZap, 1Password) start through
-- XDG autostart (home/default.nix).
hl.on("hyprland.start", function()
  hl.dispatch(hl.dsp.exec_cmd("[workspace special:mail silent] thunderbird"))
  hl.dispatch(hl.dsp.exec_cmd("[workspace special:mail silent] zoho-mail-desktop"))
end)
