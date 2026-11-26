# nixos-config

This repository holds the NixOS configuration for the ThinkPad. It includes the desktop, the applications, the development tools and the user settings. To build the system, use the command in section 2.1.

## 1. Contents

| Path | Content |
|---|---|
| `flake.nix` | Inputs (nixpkgs, Home Manager and disko), system definitions and the installer app (`apps.x86_64-linux.install`, section 4.1). |
| `hosts/thinkpad/` | Disk layout (LUKS and btrfs) and hardware settings. |
| `hosts/vm.nix` | A test virtual machine with the desktop only. |
| `hosts/thinkpad-vm/` | The full system in a virtual machine (section 9). |
| `modules/system.nix` | Boot, Nix settings, network, hardware, audio, Docker, Podman and the user. |
| `modules/desktop.nix` | Hyprland session, SDDM login, portals, keyring, fonts and input methods (fcitx5, with the theme from `home/desktop.nix`). |
| `modules/security.nix` | Firewall, Tailscale, SSH, captive portals, LocalSend and ClamAV. |
| `modules/apps.nix` | Applications. |
| `modules/dev.nix` | Languages, language servers, containers, Kubernetes and cloud tools. |
| `modules/robotics.nix` | Embedded and robotics tools, and the smart card reader. |
| `pkgs/apps.nix` | omasnap (screenshots) and monologue (webcam recorder), built from source. |
| `pkgs/ttfx.nix` | ttfx (terminal text effects) for the screensaver. It is not in nixpkgs, so the package builds the pinned source. |
| `pkgs/plymouth-theme.nix` | The boot splash theme from the desktop shell sources. |
| `pkgs/desktop-shell.nix` | The bar, panels and notifications. The package uses a fixed upstream revision and includes plugins and patches for NixOS. |
| `home/default.nix` | User settings: configuration files, Git, SSH, autostart and default applications. |
| `home/desktop.nix` | Hyprland configuration, wallpaper, night light and clipboard. The shell owns the lock screen and idle. |
| `home/theme.nix` | GTK, Qt and cursor settings, and the Zed theme. |
| `home/agents.nix` | Links the settings of Claude Code and Codex (section 10). |
| `home/calendar.nix` | Google calendar events for the clock panel (vdirsyncer and khal). The secret addresses stay in the GNOME Keyring. |
| `home/cli.nix` | Bash, aliases and command-line tools. |
| `home/hypr/` | Hyprland settings (Lua). These files change the defaults from `desktop-shell`. |
| `home/hypr-state/` | State files for desktop appearance. `home/desktop.nix` generates the theme during the build. |
| `home/shell/` | The picker (apps, clipboard, emoji, keys, system menu), written in Quickshell. |
| `home/local-ai.nix` | The local AI model servers: `llama-server` (GPU) and `flm-server` (NPU, section 4.5). |
| `modules/npu.nix` | The memlock limit for the NPU (section 4.5). |
| `pkgs/xrt.nix` | XRT and the amdxdna plugin for the AMD NPU. |
| `pkgs/fastflowlm.nix` | FastFlowLM (LLMs on the NPU), with `pkgs/fastflowlm-tokenizers-Cargo.lock`. |
| `home/location.nix` | The `weather-location` timer that gets the position from GeoClue (section 3.1). |
| `home/updates.nix` | The update watcher: timer, unlock check and the commands `system-update-check`, `system-update-available` and `system-update` (section 2.2.2). |
| `home/shell-plugins/` | Bar plugins for workspaces, tray, lid control and system readings. |
| `home/scripts/` | Helper programs for Hyprland and `nixos-menu` (the actions of the menu). |
| `home/theme/` | `colors.toml`: the one source of all theme colours (read at build time, also for the picker). `palette.nix`: maps these colours to the keys of the picker. |
| `home/config/` | Configuration files for terminals, Neovim, tmux and other applications, `shell.json` (the bar layout; the shell writes to it) and `omarchy-menu.jsonc` (the menu rows, section 3.2.1). |
| `tools/` | `install-laptop.sh` and `install.sh` (the installer, section 4.1), the test scripts `test-system-update.sh`, `test-weather-location.sh` and `test-weather-status.sh`, and `eval.sh`, `shell-preview.sh`, `vm-run.sh`, `vm-install.sh`, `vm-install-test.sh`, `vm-update.sh` and `vm-screenshot.sh`. |
| `docs/gaming.md` | Games, emulators and Wine. |

## 2. Daily use

### 2.1 Change the system

1. Edit the file in this repository.
2. Run this command:
   ```sh
   sudo nixos-rebuild switch --flake ~/Work/nixos-config#thinkpad
   ```
3. Test the change.

### 2.2 Update the system

1. Run `nix flake update` in the repository.
2. Rebuild the system (step 2.1.2).

To update one flake input, add its name to the command. For example, run `nix flake update nixpkgs` or `nix flake update desktop-shell` (section 2.2.1).

### 2.2.1 Update a desktop source

Every source is a flake input in `flake.nix`. Each input follows its project's default branch, and `flake.lock` pins the exact commit.

| Input | Upstream | Used by |
|---|---|---|
| `desktop-shell` | [omacom/omarchy](https://github.com/omacom/omarchy) | `pkgs/desktop-shell.nix`, the Plymouth theme |
| `plugin-disposable-email`, `plugin-media-control`, `plugin-nightlight` | [ajanraj/omarchy-disposable-email](https://github.com/ajanraj/omarchy-disposable-email), [debba/omarchy-media-control](https://github.com/debba/omarchy-media-control), [devSviat/omarchy-nightlight](https://github.com/devSviat/omarchy-nightlight) | the bar plugins |
| `omasnap`, `monologue` | [omacom/omasnap](https://github.com/omacom/omasnap), [omacom/monologue](https://github.com/omacom/monologue) | `pkgs/apps.nix` |
| `omazed` | [aps6/omazed](https://github.com/aps6/omazed) | the Zed theme (`home/theme.nix`) |
| `llama-cpp` | [ggml-org/llama.cpp](https://github.com/ggml-org/llama.cpp) | `pkgs/llama-cpp-vulkan.nix` |
| `disko` | [nix-community/disko](https://github.com/nix-community/disko) | disk layout and the installer |

The proprietary Superwhisper binary, XRT and FastFlowLM are `fetchurl`/`fetchFromGitHub` with a fixed hash in `pkgs/`.

1. Run `nix flake update <input>`. It moves the input to the newest commit of its branch.
2. If a patch in `pkgs/` no longer applies, refresh it against the new source.
3. Run `flock /tmp/claude-1000/heavy.lock nice -n 10 tools/eval.sh` and build the changed package.
4. Test the program, and commit `flake.lock`.

To go back, run `git checkout flake.lock`.

### 2.2.2 Update watcher

The update icon in the bar shows when updates wait. The icon is not visible when nothing waits. Point at the icon to see a short text.

When the check runs:

- Every day (the user timer `system-update-check`, with a random delay of up to 1 hour). If the computer was off, the check runs at the next start.
- After an unlock of the screen, if the last check is more than 24 hours old (the lock screen starts `system-update-unlock`; `pkgs/desktop-shell-system-update.patch`). Logind has no unlock signal for this shell, so the lock screen starts the unit itself.

What the check does (`home/scripts/system-update-check`, `home/updates.nix`):

1. It makes a newer `flake.lock` in `~/.local/state/system-update/`. It does not change the repository.
2. If an input changed, it builds the new system with this lock file (no switch). It runs with low priority. It does not build on battery power.
3. It looks for firmware updates (`fwupdmgr`).
4. It writes `~/.local/state/system-update/summary.txt` and refreshes the icon. When there is no network, the check stops and the last result stays.

The summary has three parts: **Packages** (changed inputs with the dates and the changed packages), **Firmware** (devices with the old and the new version) and **Needs** (a reboot after a change of the kernel, initrd, systemd or firmware, power connected for the firmware, power connected for the build).

To apply the updates, click the icon or use **Update > Packages** or **Update > Firmware** in the menu. The command `system-update [packages|firmware]` shows the summary and asks for each part. The package step copies the new lock file into the repository and runs `sudo nixos-rebuild switch`. It is fast because the system is already built. Then commit `flake.lock`. The firmware step runs `sudo fwupdmgr update`. Keep the power connected.

To ignore the updates that wait now, right-click the icon. The icon stays hidden until a newer update is available. The check does not install updates.

To check at once, run `systemctl --user start system-update-check`. Test: `tools/test-system-update.sh`.

### 2.3 Go back to a previous version

Each rebuild adds an entry to the boot menu. To go back, do one of these steps:

* Select the previous entry in the boot menu.
* Run `sudo nixos-rebuild switch --rollback`.

### 2.4 Files that applications change

Some applications write to their configuration files. These files are links to this repository:

* `~/.config/btop/btop.conf`
* `~/.config/zed/settings.json`
* `~/.config/nvim`
* `~/.claude/settings.json`, `~/.claude/CLAUDE.md` and `~/.codex/AGENTS.md`

Use `git status` to see the changes that these applications make. The bar layout also uses a writable file (section 3.1). To change a read-only setting, edit its source in `home/`. Then rebuild the system.

### 2.5 Project tools

`modules/dev.nix` lists the system languages and language servers. To use other versions in a project, make a development shell.

1. Add a `flake.nix` with a `devShell` to the project.
2. Add the line `use flake` to the file `.envrc` in the project.
3. Run `direnv allow` one time.

direnv loads the shell when you enter the project directory. Neovim uses the language servers from Nix.

## 3. Desktop

The Hyprland desktop uses two Quickshell programs. Hyprland starts `desktop-shell`. It shows the bar, the panels, the notifications and the volume and brightness display. A user service starts the program in `home/shell/`. It shows the picker. In the default scrolling layout, windows form columns. Each column first uses half of the screen width.

### 3.1 Bar

The bar layout is in `home/config/shell.json`. When the system has a local checkout, the bar settings write their changes to this file.

| Area | Items |
|---|---|
| Left | Menu button, workspaces, agents, vitals ("CPU 12% GPU 3% NPU 0% RAM 61% 45°C"). Click the readings to open btop. A dash marks an unavailable reading. |
| Centre, first part | Keyboard layout, lid awake, night light, world clock (Tirane, Delhi, Tokyo, San Francisco, New York). |
| Centre | Clock. Click it to show the calendar. |
| Centre, last part | Disposable e-mail, weather (forecast for 7 days). |
| Right | Tray, background apps, Tailscale, Bluetooth, media control, network, audio, monitor, power with percentage. |

To use a bar plugin, add the plugin to `pkgs/desktop-shell.nix` (from a flake input) or to `home/shell-plugins/` (our own code). Then add the plugin to `home/config/shell.json`.

Weather location: GeoClue (`services.geoclue2`, BeaconDB as provider) gives the position. The user timer `weather-location` (`home/location.nix`) writes it every 30 minutes to `~/.local/state/omarchy/settings/weather.json` with `"source":"geoclue"`. The weather panel then shows exact weather for 7 days. The bar shows the weather icon and the temperature. To set the location by hand, run `omarchy-weather-location --set <name> [lat,lon]`. The timer then does not change the file. To use GeoClue again, delete the file. The right-click notification of the weather item uses the same coordinates (`pkgs/desktop-shell-weather-status.patch`, test: `tools/test-weather-status.sh`).

Battery panel: the switch **Limit charge to 80%** stops the charge at 80% (on). When the switch is off, the battery charges to 100%. The switch uses UPower, so it needs no password.

When a network needs a sign-in page (hotel, airport), the network item shows **Sign in**. Click it to open the page.

### 3.2 Keys

| Keys | Action |
|---|---|
| Super+Space | Menu (also the logo in the bar) |
| Super+Alt+Space | Apps |
| Super+Ctrl+C | Capture menu (screenshot, screen recording, text, color) |
| Super+Ctrl+O | Toggle menu (stay awake, notifications, night light, screensaver) |
| Super+Ctrl+H | Hardware menu (laptop display, mirroring, touchpad, touchscreen) |
| Super+Ctrl+Space, Super+Ctrl+W | Background menu |
| Super+Ctrl+S | Share menu (receive files) |
| Super+Ctrl+R | Set a reminder |
| Super+Escape | System menu (lock, suspend, restart, Wi-Fi, Bluetooth, sound) |
| Super+K | List of all keys |
| Super+Ctrl+V | Clipboard history |
| Super+Ctrl+E | Emoji |
| Super+Return | Terminal |
| Super+` | Drop-down terminal |
| Super+S | Scratchpad |
| Super+Alt+F | Full width: the window uses all the width. Push again to go back to half width. On a layout that does not scroll, it maximizes the window and a second push restores it. |
| Super+Left, Super+Right | Go to the window on the left or right |
| Super+Shift+E | Mail (Thunderbird and Zoho) |
| Super+Shift+B | Default browser |
| Super+Shift+Q | Calculator |
| Super+Shift+W | Open a blank note in Neovim. The working directory is Documents. Save the note to Downloads with `:wq`. |
| Super+L | Cycle the workspace layout |
| Super+Alt+L | Cycle the workspace layout in reverse |
| Print | Screenshot (omasnap). Scroll during the capture to capture a long page. |
| Alt+Print | Screen recording (start and stop) |
| Super+Ctrl+L | Lock |
| Alt+Space | Start or stop dictation |
| Copilot key | Hold to dictate. Release to stop. |
| Ctrl+Alt+H | Word completion on or off. fcitx5 (the input method) handles this key. It shows a list of words while you type. |
| Super+I | Switch the input language. Super+Shift+I goes back. |

Press Super+K to see the active key bindings. To see them in a terminal, run `hyprctl binds`. Edit personal bindings in `home/hypr/bindings.lua`. The packaged defaults are in `$OMARCHY_PATH/default/hypr/bindings/`.

### 3.2.1 Menu

The menu is the packaged upstream menu with its own look. Press Super+Space or click the logo in the bar. The file `home/config/omarchy-menu.jsonc` adapts the rows to NixOS. A row that needs Arch Linux (pacman, AUR, limine, snapper) is hidden. A hidden menu also hides all its rows, in the search too. The helper `nixos-menu` (`home/scripts/nixos-menu`) runs the NixOS actions in a terminal. Nothing in the menu downloads from the upstream project. The rows "Learn" only open a web page.

Configuration files are read-only links to the Nix store. So a row that edits a file opens the file in the checkout (`~/Work/nixos-config`) with `$EDITOR`. After you close the editor, the terminal asks to rebuild the system.

| Menu | Rows that work | Changed or hidden |
|---|---|---|
| Apps | App list | - |
| Learn | Keybindings, Hyprland, Neovim, Bash, Tmux, Herdr. New: NixOS, Home Manager (web pages). | The upstream manual, Arch wiki and community rows are hidden. |
| Appearance | Background (the image is kept after a rebuild), Menu Bar, Windows (gaps, corners, 1-window ratio), Dock, Workspace Layout, Animations. New: Colours (opens `home/theme/colors.toml`, then rebuild and **Update > Process > Shell**). | Theme, Font, Window Opacity, Branding and Unlock are hidden. The build sets them. |
| Trigger | Toggle, Emoji, Clipboard History, Reminder, Capture, Hardware, Speed Test, Share > Receive. Screen recording uses the portal, as the Alt+Print key does. | QR Code needs `zbarimg` and Transcode needs `ffmpeg`: the rows show only when the program is on the PATH. Crash Capture, Share (send), GPU switch are hidden. |
| Setup | Monitors, Keybindings, Input (keyboard, mouse and touchpad, in `input.lua`), Config > Hyprland, Look and feel, Autostart, XCompose (no rebuild needed), Security > Fingerprint (`fprintd-enroll`), Network > QR code. | Typing, Language, DNS, Defaults, Plugins, Fido2, SSHD, SSH Agent, Sudoless Docker, Passwordless Sudo, Git, Hyprsunset, Direct Boot and Reset Computer are hidden. Nix declares them. |
| Install | Try a package (`nix shell nixpkgs#<name>`), Edit packages (`modules/apps.nix`). | All other rows are hidden. NixOS has no imperative install. |
| Remove | Edit packages (`modules/apps.nix`). | All other rows are hidden. |
| Update | Packages and Firmware (`system-update`, section 2.2.2), Rebuild, Process (Hyprsunset, Shell), Hardware (Audio, Wi-Fi, Bluetooth, Trackpad), Password > User, Time. | Channel, Kernel, Config, Extra Themes, Drive Encryption and Timezone are hidden. NixOS sets the time zone (`modules/system.nix`). |
| About | A fastfetch window. | - |
| System | Screensaver, Lock, Suspend, Logout, Reboot, Shutdown. Hibernate shows only when the system can hibernate. | - |

Super+K lists all key bindings. To change them, use **Setup > Keybindings**.

XCompose: `~/.XCompose` includes the packaged sequences, then `home/XCompose` of the checkout (your own sequences). **Setup > Config > XCompose** opens that file and restarts fcitx5 after you close the editor.

Authentication dialog: the shell has its own polkit agent (the plugin `omarchy.polkit`). It shows the dialog when an application needs root rights (for example the 1Password unlock or `pkexec`). The dialog accepts the password or the fingerprint. `services.fprintd.enable` gives the PAM service `polkit-1` fingerprint login. No other polkit agent starts.

### 3.3 Calendar events

Click the clock in the bar to see the events from your Google calendars for the next 7 days. To add, change or delete events, use Google Calendar.

Google gives each calendar a secret address in iCal format. The address stays in the GNOME Keyring (the secret store of the desktop). It is not in this repository, not in the Nix store and not in the logs. The keyring has no password of its own. The disk encryption (LUKS) protects it. The system reads the address with `secret-tool` each time it synchronizes.

To add a calendar, do these steps.

1. In Google Calendar, open Settings.
2. In the left list, select the calendar.
3. Open **Integrate calendar**.
4. Copy **Secret address in iCal format**.
5. Choose a name for the calendar (for example `personal`).
6. In a terminal, run `secret-tool store --label="Calendar personal" service vdirsyncer calendar personal`.
7. Paste the address at the prompt and press Enter. The address does not enter the shell history.
8. In `home/calendar.nix`, add the name to `calendars`. Example: `calendars = [ "personal" ];`
9. Rebuild the system (section 2.1).
10. Run `vdirsyncer discover`. Do this step one time after you add a calendar.
11. Run `vdirsyncer sync`.

The system synchronizes every 15 minutes (the `vdirsyncer` timer). To synchronize at once, run `systemctl --user start vdirsyncer`. To see the events in a terminal, run `khal list`. To check that the address is stored, run `secret-tool lookup service vdirsyncer calendar personal`. This command prints the secret address, so do not share its output. Seahorse is not installed. To show or edit the entry with it, add the `seahorse` package (**Passwords and Keys**).

To revoke an address, reset it in Google Calendar (**Integrate calendar**, **Reset**). Then run the `secret-tool store` command again with the new address.

## 4. Installation

> **WARNING:** The installation erases the internal disk, including `/home`. Make a backup of your files before you start.

### 4.1 Install NixOS

Use the official NixOS minimal ISO from https://nixos.org/download/. This repository has no custom ISO and no package cache. The installer gets the newest package versions from the network.

1. Write the ISO to a USB drive. Start the computer from it. The ISO logs in as the user `nixos`.
2. Connect to Wi-Fi. Run `nmtui`, select **Activate a connection**, and select your network. A cable connection needs no step.
3. Run this command. The ISO does not turn on `nix-command` and `flakes` by default, so the command has the option for them.
   ```sh
   nix run --extra-experimental-features 'nix-command flakes' github:somethim/nixos#install
   ```
   The installer shows the NixOS logo. If the computer has no network, `nmtui` opens.
4. Answer the questions. Each question has the current value. Press Enter to keep it.

   | Field | Notes |
   |---|---|
   | Username | Lowercase letters, digits, `-` and `_`. |
   | Password | Type it two times. It is the disk password and the user password. |
   | Full name | Used for the user and for `git`. |
   | Email address | Used for `git`. |
   | Hostname | The name of the computer. |
   | Timezone | Type to search the list. |
   | Keyboard | Type to search the list of layouts. |
5. Read the table. Select **Yes** at **Does this look right?**. Select **No, change it** to answer the questions again.
6. On the laptop with more than one internal disk, select the disk. The installer medium is not in the list. A red warning shows the disk that the installer erases. Select **Erase and install**.
7. Wait. The installer shows each step and the time. It saves the full output in `/tmp/install.log`. If a step fails, it shows the last lines of the log.
8. The last screen shows **Installed in …** and **Remember to remove the USB drive!** Select **Reboot now**. Remove the USB drive.

What the installer does:

1. It copies the flake (the source of the command, `self`) to a writable folder in `/tmp` and makes a Git repository there.
2. It writes your answers to `identity.json`. It does not write the password there.
3. It runs `nix flake update`. The installed system has the newest versions, not the versions of the last commit.
4. It runs disko (LUKS and btrfs), `nixos-generate-config` and `nixos-install` from this copy.
5. It copies the checkout, with the new `flake.lock` and the generated `hardware-configuration.nix`, to `~/Work/nixos-config` (host `thinkpad`) or `~/nixos-config` (host `thinkpad-vm`).

To change an answer later, edit `identity.json` and rebuild the system.

A script can give the answers in the variables `INSTALL_USER`, `INSTALL_PASSWORD`, `INSTALL_FULLNAME`, `INSTALL_EMAIL`, `INSTALL_HOSTNAME`, `INSTALL_TIMEZONE`, `INSTALL_KEYBOARD` and `INSTALL_DISK`. `INSTALL_YES=1` answers Yes to all confirmations. The installer chooses the host `thinkpad-vm` in a virtual machine and `thinkpad` on the laptop. To use the other host, add `-- thinkpad-vm` or `-- thinkpad` at the end of the command.

### 4.2 First start

1. Type the disk password. The system logs in automatically.
2. Run this command. The installer made the checkout `~/Work/nixos-config`. It has the `hardware-configuration.nix` of this computer. Do not clone the repository again before the first rebuild.
   ```sh
   sudo nixos-rebuild switch --flake ~/Work/nixos-config#thinkpad
   ```
3. Commit the generated `hosts/thinkpad/hardware-configuration.nix` and `flake.lock` in the checkout. The checkout has the remote `origin` (`https://github.com/somethim/nixos.git`).
4. Download the local AI models (section 4.5).

Home Manager makes the empty folders `~/Documents`, `~/Downloads`, `~/Music`, `~/Pictures`, `~/Videos`, `~/Work`, `~/Projects`, `~/Learning`, `~/Portfolio`, `~/Career` and `~/Games`. It does not clone any repository.

### 4.3 SSH and commit signing

The system runs the standard OpenSSH agent (`services.ssh-agent`). Keys are in `~/.ssh`.

1. Make a key with `ssh-keygen -t ed25519`. The key is `~/.ssh/id_ed25519`.
2. If the key has a passphrase, run `ssh-add` after each login. After the first use, `AddKeysToAgent yes` keeps the key in the agent for the rest of the session.
3. On GitHub, make sure that `~/.ssh/id_ed25519.pub` is an **Authentication key** and a **Signing key**.
4. To sign commits, set `signCommits = true` in `home/default.nix`. Rebuild the system. The rebuild writes `~/.config/git/allowed_signers` from the public key.

1Password stays as an application for passwords. It does not manage SSH keys.

### 4.4 Remaining tasks

* Run `sudo tailscale up`.
* Run `fprintd-enroll` to add your fingerprint.
* Run `gh auth login`.
* Install the Blender MCP server (Blender Lab):
  ```sh
  git clone https://projects.blender.org/lab/blender_mcp.git ~/blender_mcp
  blender --command extension build --source-dir ~/blender_mcp/addon/blender_mcp_addon --output-dir /tmp/mcp
  blender --command extension install-file --repo user_default --enable /tmp/mcp/*.zip
  claude mcp add --scope user blender -- uv --directory ~/blender_mcp/mcp run blender-mcp
  ```
  Then, in Blender, open **Edit > Preferences > Add-ons > MCP** and select **Auto-start**.

The autostart applications start hidden in the tray: Steam (`-silent`), Discord (`--start-minimized`), 1Password (`--silent`), ZapZap (`--hideStart`) and Heroic (`--no-gui`). WeChat does not start at login.

### 4.5 Local AI models

The model files are not in this repository. Hugging Face is the source of each file.

| File | Size | Source |
|---|---|---|
| `Inkling-2-Mini-IQ4_NL.gguf` | 17.6 GB | `ggml-org/Inkling-2-Mini-GGUF` |
| `Inkling-2-Mini-Uncensored-AD-IQ3_S.gguf` | 13.3 GB | `AtomicChat/Inkling-2-Mini-Uncensored-GGUF` |
| Two `mmproj` vision files | - | The same two repositories |

After the installation, do these steps.

1. Download the files into `~/.local/share/models`. Use the repositories in the table.
2. Start the server: `systemctl --user start llama-server`.

The server (`home/local-ai.nix`) uses llama.cpp with Vulkan. The API is on `127.0.0.1:8080`. The server reads the models from `~/.local/share/models` (`--models-dir`). It loads one model at a time (`--models-max 1`). It does not start at login.

#### NPU (FastFlowLM)

The service `flm-server` (`home/local-ai.nix`) runs FastFlowLM with `qwen3.5:9b` on the AMD NPU.
The API is on `127.0.0.1:52625`. The OpenCode profile `npu` uses this address. The service does not start at login.
The model files are in `~/.local/share/flm` (the variable `FLM_MODEL_PATH`).

The packages build, but nobody has run them on the NPU yet. After the installation, do these steps.

1. Log in again, so that the memlock limit applies. Check: `ulimit -l` shows `unlimited`.
2. Check the driver and the firmware: `lsmod | grep amdxdna` and `ls /dev/accel/accel0`.
3. Check the stack: `xrt-smi examine` shows the NPU, and `flm validate` shows no error.
4. Download the model (network, several GB): `flm pull qwen3.5:9b`.
5. Test in the terminal: `flm run qwen3.5:9b`.
6. Start the server: `systemctl --user start flm-server`. Test it:
   `curl http://127.0.0.1:52625/v1/models`.

If `flm run` fails and `flm validate` passes, run `xrt-smi examine` and read its error.

## 5. Network and security

| Item | Configuration |
|---|---|
| Firewall | Blocks all incoming connections. Exceptions: Tailscale, LocalSend (port 53317), Steam Remote Play and mDNS. |
| Docker | Published container ports go around the firewall. On the default bridge, a port with no host address (`-p 8080:80`) binds to `127.0.0.1` only. To open a port to the LAN on purpose, write `-p 0.0.0.0:8080:80`. Compose networks that you define yourself ignore this default. In each port mapping, write `127.0.0.1:`. |
| SSH | Keys only. No passwords. No root login. Available through Tailscale only. |
| Tailscale | Exit nodes operate. Files that you send with Taildrop go to `~/Downloads`. |
| Captive portals | NetworkManager checks `nmcheck.gnome.org`. The bar shows **Sign in** when a portal blocks the connection. |
| Phone | Install LocalSend on the phone to send files and text to the laptop on the same network. Away from home, use Taildrop. |
| ClamAV | Scans files in `~` when they are saved. Skips caches, tool folders, games, containers, `~/Work` and `~/Projects`. Quick scan: every day at 13:00. Full scan of `~`: every Sunday at 14:00. |

Run this command to see ClamAV results.

```sh
journalctl -u clamav-clamonacc -u clamdscan -u clamav-weekly-home | grep FOUND
```

## 6. Smart card reader

The card slot is a smart card reader. Use it for OpenPGP and PIV cards. These cards keep keys on the card. To test a card, run `pcsc_scan`.

## 7. Desktop integration

* **Compose key.** The Shift+Caps Lock rule is in `/etc/xkb`. Hyprland reads keyboard rules through libxkbcommon. libxkbcommon reads custom rules from `/etc/xkb`. The NixOS option `extraLayouts` applies to the X server only.
* **OMARCHY_PATH.** `modules/desktop.nix` sets the session variable `OMARCHY_PATH`. Hyprland uses it to find the defaults and helper commands from `desktop-shell`.
* **Login screen.** SDDM runs on Wayland. The greeter uses Hyprland. `desktop-shell` supplies the greeter settings and theme. SDDM logs in automatically and starts the `hyprland-uwsm` session. Home Manager writes the user files before SDDM starts.
* **Rounded corners and other toggles.** The Hyprland defaults load the toggle files in `~/.local/state/omarchy/toggles/hypr` with `find -type f`, which skips links. So Home Manager copies these files and does not link them.
* **First-start steps of the desktop.** The Hyprland defaults start a first-start step at login. Its steps are for Arch Linux, or this configuration sets them already. So it shows errors and notices that do not apply. Home Manager writes the marker file `~/.local/state/omarchy/done/first-run-user` (`home/desktop.nix`). The step then does nothing.
* **Screensaver.** The screensaver shows a snowflake in block characters from `home/config/branding/screensaver.txt`. Home Manager links it to `~/.config/omarchy/branding/screensaver.txt`, where the screensaver reads its text. The screensaver runs `ttfx` (`pkgs/ttfx.nix`). To change the picture, change that file.
* **Browser.** Brave Origin (`pkgs.brave-origin`) is the default browser: `xdg.mimeApps` in `home/default.nix` sets it for web links and HTML files, and Super+Shift+B opens it. Select **Proceed with Origin for free** at the first start. `programs.brave` (`modules/apps.nix`) installs it and writes the managed policy `/etc/brave/policies/managed/default.json`, which force-installs the extensions 1Password, Claude in Chrome, Dark Reader, DuckDuckGo, Snowflake and uBlock Origin Lite. Chromium has the same extensions and opens the app windows (Claude, ChatGPT, Missing Manual).
* **Missing Manual.** The launcher has an entry for the Missing Manual website. It opens in a Chromium app window (`home/default.nix`).
* **Keyring.** SDDM logs in without a password, so no password can unlock a keyring at login. When no keyring exists, Home Manager writes an unencrypted login keyring (`home/default.nix`). The disk encryption protects it. Home Manager never changes an existing keyring. A restored keyring that has a password stays locked and asks for its password.
* **Boot splash.** `modules/desktop.nix` turns on Plymouth with the systemd initrd, so the disk password prompt shows in the splash. The theme comes from the desktop shell sources (`pkgs/plymouth-theme.nix`).
* **Autostart in the tray.** XDG autostart (`home/default.nix`) starts Steam (`-silent`), Discord (`--start-minimized`), 1Password (`--silent`), ZapZap (`--hideStart`) and Heroic (`--no-gui`) hidden in the tray. WeChat does not start at login.
* **Thunderbird mail area.** Thunderbird has no tray icon on Linux. The system starts Thunderbird and Zoho on a hidden workspace. Super+Shift+E shows and hides this workspace.

## 8. Open items

* **Packet Tracer.** Add the `.deb` file to the Nix store. Then remove the comment marks in `modules/apps.nix`.
* **AMD NPU.** XRT and FastFlowLM are not in nixpkgs. The repository packages them (section 4.5). The packages build, but nobody has tested them on the NPU. Do the NPU test on the ThinkPad. The GPU path (llama.cpp with Vulkan) is the working path.

## 9. Test the full system in a virtual machine

Before you erase the laptop disk, install the full system in a virtual machine (VM). The VM uses the same modules and disk layout. It uses 3D graphics for the wallpaper and blur. The VM disk is in `~/VMs/thinkpad-vm`.

### 9.1 Prepare the host

On the current system, install QEMU and the UEFI firmware:

```sh
omarchy pkg add qemu-desktop edk2-ovmf
```

### 9.2 Install the system in the VM

1. Copy the official NixOS minimal ISO to `~/.cache` (the script takes the newest `nixos-minimal-*-x86_64-linux.iso` there, or the file in `VM_ISO`).
2. Run `flock /tmp/claude-1000/heavy.lock nice -n 10 tools/vm-install.sh install`. The ISO starts in a window. The VM has network access.
3. In the VM, run these commands. The VM shows this repository as the 9p share `config`. The command uses this folder, not GitHub, so you can test a change that you did not push.
   ```sh
   sudo mkdir -p /cfg && sudo mount -t 9p -o trans=virtio,ro config /cfg
   nix run --extra-experimental-features 'nix-command flakes' path:/cfg#install
   ```
   The command chooses the host `thinkpad-vm` and the disk `/dev/vda`.
4. Answer the questions of section 4.1 (step 4). Press Enter to keep each value. Type a password two times. It is the disk password and the user password of the VM.
5. Select **Yes**, then **Erase and install**.
6. On the last screen, select **Power off now**.

### 9.3 Use the VM

1. Run `flock /tmp/claude-1000/heavy.lock nice -n 10 tools/vm-install.sh`.
2. Type the disk password. The system logs in automatically.
3. Click in the window. Push Ctrl+Alt+G to send all keys (also Super) to the VM. Push Ctrl+Alt+G again to release the keys.

Run this command in the VM to apply a change from this repository.

```sh
bash /mnt/config/tools/vm-update.sh
```

The VM shows this repository at `/mnt/config`. The script copies it to `~/nixos-config` and rebuilds the system.

To start again with an empty VM, delete `~/VMs/thinkpad-vm`.

### 9.4 Test the installation automatically

A script installs `thinkpad-vm` with the steps of sections 4.1 and 4.2. It needs no key presses and no window. It uses a new empty virtual disk in `~/.cache/nixos-config-install-test` and the test password `vmtest-pass`. It never uses `~/VMs`.

```sh
flock /tmp/claude-1000/heavy.lock nice -n 10 tools/vm-install-test.sh
```

1. The script exports the tracked files of this repository to the scratch directory. It never writes to the ISO.
2. It boots the official NixOS minimal ISO (the kernel and initrd of the ISO, with a serial console) with network access. It mounts the exported files and runs `nix run path:/cfg#install` on the serial console. It gives the answers in the `INSTALL_*` variables (host name `test-vm`, time zone `Europe/Berlin`, keyboard `de`). `path:` makes the test use the local commit, not GitHub.
3. It starts the installed system, types the disk password, and waits for the desktop.
4. It saves screenshots in `tools/out/install-*.png` and the logs in `tools/out/install-installer.log` and `tools/out/install-serial.log`.
5. It shows PASS or FAIL for each check. One check makes sure that `nix flake update` ran before disko. The exit status is not zero when a check fails.

The test takes 40 to 120 minutes. The installer builds the system from `cache.nixos.org`. The test uses 25 to 45 GB in the scratch directory. When the test is done, delete this directory. To use a different directory, set `VM_TEST_DIR`.

## 10. Agent settings

`home/agents.nix` links `~/.claude/settings.json`, `~/.claude/CLAUDE.md`, `~/.claude/scripts/statusline.sh` and `~/.codex/AGENTS.md` to `home/config/claude/` and `home/config/codex/`. The settings file contains no secrets. Keep it so. The `SessionStart` hook in it runs `~/.claude/hooks/herdr-agent-state.sh` (an absolute path, because herdr writes it this way and writes it again after an update). Home Manager installs the herdr hooks for Claude Code (`~/.claude/hooks/herdr-agent-state.sh`) and Codex (`~/.codex/herdr-agent-state.sh` and `~/.codex/hooks.json`) from `home/config/`, as read-only files. The herdr hooks for opencode are in `home/config/opencode/`.

The agent skills come from the public repository `somethim-omarchy/agent-skills` (the flake input `agent-skills`). `home/agents.nix` links each skill folder to `~/.claude/skills/<name>` and `~/.agents/skills/<name>`. The links are read-only. To change a skill, change it in that repository and push it. Then run `nix flake update agent-skills` and `nixos-rebuild switch`.

To refresh the herdr hooks after a herdr update: run the herdr integration install on a computer that is not managed by Home Manager (or in a test home folder), copy the new files over the ones in `home/config/claude/hooks/`, `home/config/codex/` and `home/config/opencode/`, and run `nixos-rebuild switch`. The files in the repository are from herdr integration version 10.
