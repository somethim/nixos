# Plan: open work (written 2026-11-23, updated 2026-11-24)

## 1. Bar and panels: use the upstream shell code (user decision)

Goal: the NixOS bar looks and works like the current laptop bar. Copy the MIT code, package it
in Nix, pinned. Decisions already made by the user:
- Keep upstream names inside the packaged code (no rename). Keep the MIT LICENSE files.
  Nothing in the user's config, bar labels or docs mentions the upstream project.
- Do NOT copy the foamy plugins (vitals, weather, monitor). Use the upstream built-in panels:
  weather must show a full 7-day forecast (patch the built-in weather panel), monitor panel
  as close as possible to the current controls, vitals in the same style (RAM xx%, left side).

Sources (pin these):
- Shell: https://github.com/omacom/omarchy, directory `shell/` (Commons, Ui, services, plugins).
  Installed version is 4.5.0-3; tag `v4.5.0` exists. `shell/` at HEAD differs from the
  installed copy in 22 files: pick the tag that matches, or the newest stable tag.
- Helper scripts: the same repo, `bin/`. Package only the ~40 helpers that the kept parts call
  (list: grep `omarchy-[a-z0-9-]+` in the kept dirs). Skip Arch-only ones (pkg, update, limine,
  snapper). The full closure (~318) is only reached through the menu plugin: do not use it.
- Plugins (git, pin by rev):
  - io.github.ajanraj.disposable-email  https://github.com/ajanraj/omarchy-disposable-email  ed260e6  (DuckDuckGo provider)
  - sviat.nightlight                    https://github.com/devSviat/omarchy-nightlight       937bd29
  - debba.media-control                 https://github.com/debba/omarchy-media-control       62c3ea7
  - somethim.lid-awake                  https://github.com/somethim-omarchy/omarchy-lid-awake da5c7ee
  - somethim.tray, somethim.workspaces: local only, in
    ~/.config/omarchy/plugins/ on the old laptop. Copy into this repo (user's own code).

Target bar layout (from ~/.config/omarchy/shell.json, reference screenshots in tools/ref/):
- left:   menu button, workspaces (numbers), vitals ("RAM 61%")
- center: lid-awake, nightlight, world clock (elsewhen: Tirane, Delhi, Tokyo, San Francisco,
          New York) | clock "ddd d MMM HH:mm" with calendar panel | disposable email, weather
- right:  tray, tailscale, bluetooth, media-control, network, audio,
          monitor, power with percentage

Status (2026-11-23):
- Done: local sources in `vendor/` (shell and three plugins), `pkgs/desktop-shell.nix` (shell v4.5.0,
  nord theme, path and 7-day weather patches, wrappers `desktop-shell`, `desktop-shell-ipc`,
  `desktop-shell-toggle-bar`), overlay in `modules/desktop.nix`, user service, plugin links,
  writable `home/config/shell.json`, picker kept in `home/shell/` (bar, calendar,
  notifications and their scripts removed), Hyprland bindings for notifications, calendar and
  the full-screen-desktop bar toggle, night light through hyprsunset (replaces wlsunset).
- Vitals (CPU, GPU, NPU, RAM, temperature): the `somethim.vitals` plugin is in the left bar
  (`home/config/shell.json`, `home/shell-plugins/somethim.vitals`).
- Calendar events: the clock panel reads khal (`desktop-shell-calendar-events.patch`,
  `home/calendar.nix`: vdirsyncer and khal).
- Volume and brightness display: only the upstream display shows (local OSD removed).
- Idle and lock: only the shell locks (idle service and `sleep-lock` user service).
- somethim.lid-awake: the repo is private (the flake cannot fetch it), so its code is copied to
  `home/shell-plugins/` like the other own plugins.
- Weather location (done): GeoClue gives the position (`home/location.nix`, every 30 minutes).
  A location that the user sets by hand wins. The bar shows the weather icon and the temperature.
- Calendar addresses (done): the iCal addresses are in the GNOME Keyring. The system reads them
  with `secret-tool` (README 3.3).
- Left:
  - Store each iCal address with `secret-tool` and add the names to `calendars` in
    `home/calendar.nix` (README 3.3). Then check that events show in the clock panel (VM or laptop).
  - Check on the real laptop: one volume display per key press, lock after 300 s idle, lock before suspend.
  - Check on the real laptop: tray, media control, disposable e-mail, tailscale, power panel.
  - Compare the VM result with `tools/ref/*.png` (the VM has no GPU, no wallpaper).

## 2. Browser extensions and startup applications

Brave Origin is the default browser (`xdg.mimeApps` in `home/default.nix`). Brave Origin and
Chromium use managed extension policies (`programs.brave` writes `/etc/brave/policies/managed`,
`programs.chromium` writes `/etc/chromium/policies/managed`). Both use uBlock Origin Lite.
Claude in Chrome is available from the Chrome Web Store.
Test extension installation in new profiles in the full VM.

Startup applications start hidden in the tray (`home/default.nix`):
- Steam: `-silent`.
- Discord: `--start-minimized`.
- 1Password: `--silent`.
- ZapZap: `--hideStart`.
- Heroic: `--no-gui`.

## 3. Other open items
- Full-width toggle: Super+Alt+F (one state) is done on the laptop and in the config.
- The installer is the flake app `install` (`nix run github:somethim/nixos#install` in the official
  NixOS minimal ISO, README 4.1). `tools/vm-install-test.sh` tests it end to end in a fresh VM
  with no input (it runs the app from the local working tree).

## 4. Local AI models (user decision 2026-11-23)

Status (2026-11-24): the model files are downloaded and checked (sha256 matches Hugging Face).
They are in `~/.local/share/models` (README 4.5).
The NPU packages (XRT, the amdxdna plugin and FastFlowLM) are written and build (2026-11-24).
They are not tested on the NPU: that needs the ThinkPad (README 4.5, "NPU test").
The GPU path (llama.cpp with Vulkan) is the working path.

Hardware: Ryzen AI 7 PRO 350, Radeon 860M, XDNA2 NPU and 30 GB RAM.

1. NPU (packaged, not tested on the hardware): FastFlowLM runs `qwen3.5:9b` on the NPU. The OpenCode
   profile (`home/config/opencode/npu.json`) uses this model on `127.0.0.1:52625`.
   The locked nixpkgs has neither XRT nor FastFlowLM, so the repository packages them:
   - Kernel: the locked kernel is 7.3.5 and has `CONFIG_DRM_ACCEL_AMDXDNA=m` (the module `amdxdna`).
     FastFlowLM needs kernel 7.0 or newer. The firmware is in linux-firmware 20261019
     (`amdnpu/17f0_10`, `17f0_11` and `1502_00`, with `npu_7.sbin`; `hardware.enableRedistributableFirmware`
     is on). Nothing is missing. The ThinkPad (PCI `1022:17f0`, revision 0x20) loads the firmware
     `amdnpu/17f0_10/npu_7.sbin` with the same driver on Arch Linux.
   - `pkgs/xrt.nix`: XRT 2.21.75 for the NPU only (no Alveo, no FPGA) and the amdxdna plugin
     (`libxrt_driver_xdna.so.2`), both from the tag 2.21.75 of `amd/xdna-driver` with its XRT submodule.
     This is the version of the Arch Linux packages that FastFlowLM documents. Licence: Apache-2.0 and
     GPL-2.0-only (XRT). The source is fetched with a fixed hash (424 MB, too big for `vendor/`).
     XRT finds the plugin in its own install directory, so one package holds both.
   - `pkgs/fastflowlm.nix`: FastFlowLM 1.0.13, built from the source tag `v1.0.13` (with submodules,
     fixed hash). The Rust tokenizer uses `pkgs/fastflowlm-tokenizers-Cargo.lock` (upstream has no lock file).
     Licence: the runtime is MIT. The NPU kernels (`.xclbin`) and the prebuilt engine libraries are
     proprietary (FastFlowLM NPU Binary License): free for any use, redistribution only unmodified.
     The package is `mit` and `unfreeRedistributable`. `allowUnfree` is already on.
   - `modules/npu.nix`: the memlock limit of the user is `unlimited` (the driver pins the model memory).
     The device `/dev/accel/accel0` is open to all users (rule of systemd), so there is no extra udev rule.
   - `home/local-ai.nix`: the user service `flm-server` (`flm serve qwen3.5:9b`, port 52625, model files
     in `~/.local/share/flm`). It does not start at login. The model files need `flm pull qwen3.5:9b`
     once (network).
2. Official model: use the [GGUF from ggml-org](https://huggingface.co/ggml-org/Inkling-2-Mini-GGUF),
   which uses the Thinking Machines Lab weights.
3. Community model: use IQ3_S from
   [AtomicChat](https://huggingface.co/AtomicChat/Inkling-2-Mini-Uncensored-GGUF).

The locked nixpkgs package uses llama.cpp build 12359. The ThinkPad service
uses a Vulkan build pinned to b12631, with the API on `127.0.0.1:8080`.
Keep model files in `~/.local/share/models`. Start the service when needed
with `systemctl --user start llama-server`. The service loads up to one model
at a time. Check inference on the ThinkPad after you add the model files.

## 5. Lookup TUI for unknown senders (user project, 2026-11-23)

The user builds this themselves. Claude does not write its code: only answer questions, review, or
package the four back-end tools in this flake if asked.

Goal: one terminal app to check who an unknown email address, phone number or username
belongs to before replying (like fingerprint.to, an OSINT search engine). No existing TUI
combines these tools; the user wants to build one.

Back ends (run as subprocesses, machine-readable output; check nixpkgs, package what is missing):
- holehe: email -> sites with an account.
- PhoneInfoga: phone -> country, carrier, line type, search results (`phoneinfoga serve` has a JSON API).
- Maigret: username -> ~3000 sites, recursive, JSON report (`--json`).
- SpiderFoot: everything, recursive, ~200 modules (`sf.py` CLI with JSON output, or its local web API).

TUI design (first version):
- One input field. Detect the type (email / phone / username).
- Run the matching back ends in parallel; show a live panel per back end.
- New usernames/emails found in results become clickable to start the next search (the recursive
  part of fingerprint.to).
- Keep a local history (SQLite) of searches and results.
- Read-only: no messages to the person, no accounts created.

Stack choice (ask the user): Rust + ratatui (fits the zero2prod / Rust learning, one static binary,
packaged with rustPlatform.buildRustPackage) or Python + Textual (same language as the back ends).
Repo: its own project under ~/Projects, packaged into this flake as an input once usable.

## 6. Dictation (speech to text): package Superwhisper itself (user request 2026-11-23)

Preferred: package the user's app, Superwhisper for Linux (proprietary, unfree; host has
superwhisper-bin 1.3.1, files in /opt/superwhisper/bin: superwhisper, superwhisper-indicator,
asr-worker*, cleanup-worker*; deps glibc gtk4 gtk4-layer-shell python3+gobject+cairo
pipewire-pulse libnotify wl-clipboard ffmpeg vulkan-loader librsvg fontconfig at-spi2-core foot).
Package like other unfree binaries in nixpkgs: fetchurl from the OFFICIAL download (find the URL
the upstream package uses; ask the user if there is no public download: packaging the local copy is
a licence question for the user), autoPatchelfHook, wrapGAppsHook4, makeWrapper for PATH.
Also package the bar plugin `superwhisper-panel` (~/.config/omarchy/plugins/superwhisper-panel).
Fallback if packaging is not possible: the open alternatives below.

- Keys: keep the Superwhisper bindings: Alt+Space = start/stop (toggle) dictation, plus the
  push-to-talk key from the live config (check ~/.config/hypr bindings / superwhisper binding).
  Text is typed into the focused window.
- A remote (cloud) speech-to-text service is fine for the user (decision 2026-11-23); a local model
  is not required. Pick a front end that supports both a remote API (e.g. an OpenAI-compatible
  /audio/transcriptions endpoint) and local whisper.cpp. API key from 1Password (op), not in the repo.
- Engine: whisper.cpp with Vulkan on the Radeon 860M, model Whisper large-v3-turbo (model file in
  ~/.local/share/models, downloaded by the user). NPU: check the FastFlowLM model list for a Whisper
  model on Linux; Lemonade's NPU whisper backend is Windows-only (checked 2026-11-23). Do not guess.
- Front end: Voxtype (Wayland push-to-talk on whisper.cpp; check if the current upstream shell uses it)
  or hyprwhspr. Check nixpkgs first; package if missing.
- Bar: a recording indicator (check if the packaged shell has one for its dictation integration).

## 7. Theme, Neovim, bindings (done 2026-11-23, checked in the headless VM)
- Theme: `nordTheme` (home/desktop.nix) runs the packaged template scripts at build time (glass on,
  opacity 0.65). Output = live ~/.local/state/omarchy/current/theme byte for byte (only the store
  path of glass.css differs). App configs include it as on the live host. GTK Adwaita-dark, icons Yaru-blue.
- Neovim: programs.neovim in home/cli.nix (sideloadInitLua, so the LazyVim init.lua stays linked).
  foot, ghostty, alacritty and the share picker are installed; home/hypr/xdph.conf selects the picker.
- Bindings: dead web-app keys unbound (WhatsApp web, Messages, YouTube, Photos, Maps, X, X Post, agent).
