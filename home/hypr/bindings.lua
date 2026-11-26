-- Personal overrides layered on top of the upstream desktop defaults.

-- WhatsApp replaces Signal.
-- NixOS: ZapZap is the WhatsApp client (the Arch host runs a web app).
o.rebind("SUPER + SHIFT + G", "WhatsApp", { focus = "zapzap", launch = "zapzap" })

-- Obsidian is not installed.
hl.unbind("SUPER + SHIFT + O")

-- Claude and ChatGPT.
-- Both open as Chromium app windows.
o.rebind("SUPER + SHIFT + A", "Claude", "uwsm-app -- chromium --app=https://claude.ai/new")
o.rebind("SUPER + SHIFT + ALT + A", "ChatGPT", "uwsm-app -- chromium --app=https://chatgpt.com/")

-- Mail: Thunderbird replaces HEY; Zoho Mail beside it.
-- NixOS: both live on the hidden "mail" workspace (autostart.lua). Super+Shift+E shows and
-- hides it, or focuses Thunderbird.
local function is_mail(window)
  local class = ((window and window.class) or ""):lower()
  return class:find("thunderbird", 1, true) ~= nil or class:find("zoho", 1, true) ~= nil
end
o.rebind("SUPER + SHIFT + E", "Thunderbird", function()
  if is_mail(hl.get_active_window()) then
    hl.dispatch(hl.dsp.workspace.toggle_special("mail"))
    return
  end
  for _, window in ipairs(hl.get_windows() or {}) do
    if ((window.class or ""):lower()):find("thunderbird", 1, true) then
      hl.dispatch(hl.dsp.focus({ window = "address:" .. window.address }))
      return
    end
  end
  hl.dispatch(hl.dsp.exec_cmd("[workspace special:mail] thunderbird -mail"))
end)
-- The bar clock opens the calendar.
hl.unbind("SUPER + SHIFT + C")
hl.unbind("SUPER + SHIFT + RETURN")
hl.unbind("SUPER + SHIFT + ALT + B")
o.rebind("SUPER + SHIFT + B", "Browser", { omarchy = "browser" })
o.rebind("SUPER + SHIFT + ALT + E", "New email", "thunderbird -compose")
-- NixOS: focus the Zoho Mail window or start it.
o.bind("SUPER + ALT + E", "Zoho Mail", { focus = "zoho mail", launch = "zoho-mail-desktop" })

-- Super+Q/W: the Arch host hides enabled background apps (background-app-close.lua).
-- NixOS: no such plugin; the default close bindings stay.

-- The key right of Space is a Copilot key (sends Super+Shift+F23, code:201).
hl.unbind("SUPER + SHIFT + code:201")
hl.unbind("ALT + Alt_R")
o.rebind("ALT + SPACE", "Toggle dictation", "superwhisper record")
o.bind_hold("SUPER + SHIFT + code:201", "Start dictation", "superwhisper start",
  "Stop dictation", "superwhisper stop")

-- Full width (one state): the focused column toggles full <-> half width; the others
-- stay half wide and Super+Left/Right reaches them.
-- NixOS: hypr-focus-width is a package on PATH (home/desktop.nix), not ~/.local/bin.
o.rebind("SUPER + ALT + F", "Full width (toggle)", "hypr-focus-width")

----------------------------------------------------------------------------
-- NixOS only. The menu hides the rows that need Arch Linux (home/config/omarchy-menu.jsonc)
-- and some upstream apps are not installed. Each rebind below maps a default binding
-- to what exists here; each unbind drops one that has nothing to open.
----------------------------------------------------------------------------

-- The menu keys stay as upstream: Super+Space (root menu), Super+Alt+Space (apps), Super+Ctrl+C
-- (capture), Super+Ctrl+O (toggle), Super+Ctrl+H (hardware), Super+Ctrl+Space and Super+Ctrl+W
-- (background), Super+Ctrl+S (share), Super+Ctrl+R (reminder). Only the labels change.
o.rebind("SUPER + SPACE", "Menu", { menu = "root" })

-- The system (power) menu is the picker in home/shell.
o.rebind("SUPER + ESCAPE", "System menu", "quickshell ipc -c desktop call picker toggle system")
o.rebind("XF86PowerOff", "Power menu", "quickshell ipc -c desktop call picker toggle system", { locked = true })

-- The theme is fixed at build time, so the theme menu has no rows.
hl.unbind("SUPER + SHIFT + CTRL + SPACE") -- theme menu
hl.unbind("SUPER + CTRL + T")             -- theme menu

-- Default web-app keys. This build has no web apps besides Claude and ChatGPT (above), and
-- WhatsApp is ZapZap on Super+Shift+G.
hl.unbind("SUPER + SHIFT + ALT + G")  -- WhatsApp web app (duplicate of ZapZap)
hl.unbind("SUPER + SHIFT + CTRL + G") -- Google Messages
hl.unbind("SUPER + SHIFT + Y")        -- YouTube
hl.unbind("SUPER + SHIFT + P")        -- Google Photos
hl.unbind("SUPER + SHIFT + S")        -- Google Maps
hl.unbind("SUPER + SHIFT + X")        -- X
hl.unbind("SUPER + SHIFT + ALT + X")  -- X Post

-- The agent launcher needs a default agent picked from the upstream menu, which is not here.
hl.unbind("SUPER + SHIFT + CTRL + A")

-- Screen recording: one toggle through the upstream recorder helper (portal capture, as before).
-- The bar indicator runs the same command, so its --status check sees this recording.
o.rebind("ALT + PRINT", "Screenrecording", "env OMARCHY_SCREENRECORD_USE_PORTAL=true omarchy-capture-screenrecording")

-- Apps the upstream launchers expect from Arch paths or from the upstream apps.
o.rebind("SUPER + SHIFT + Q", "Calculator", "gnome-calculator")
o.rebind("XF86Calculator", "Calculator", "gnome-calculator")
o.rebind("SUPER + SHIFT + M", "Spotify", { focus = "spotify", launch = "spotify" })
o.rebind("SUPER + SHIFT + W", "Write in Neovim",
  [=[sh -c 'docs="$HOME/Documents"; downloads="$HOME/Downloads"; mkdir -p "$docs" "$downloads" && cd "$docs" && exec xdg-terminal-exec nvim "$downloads/note-$(date +%F_%H-%M-%S-%N).md"']=])

-- Word completion belongs to fcitx5 (keyboard addon). This entry only shows the key in the Super+K
-- list. non_consuming passes the key on to the focused app, so fcitx5 still gets it.
o.bind("CTRL + ALT + H", "Word completion on or off", function() end, { non_consuming = true })
