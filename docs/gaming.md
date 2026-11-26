# Games

`modules/apps.nix` installs Heroic, RetroArch (mGBA and melonDS cores) and GameMode. Home Manager creates `~/Games` (`home/default.nix`) and does not replace existing files. Wine (64-bit, with Wayland support), winetricks, unrar and rsync are installed. The system does not install games, graphics drivers or the 3DS core.

## Pokémon and RetroArch

1. Open RetroArch, then **Load Core**. Select mGBA for `.gba` files or melonDS for `.nds` files.
2. Select **Load Content**. Select a file in `~/Games/Pokemon`.
3. Set the controller in **Settings > Input**.

For Pokémon Y (`.cci`), use the Azahar core from **Online Updater > Core Downloader** when it is available. If it is not available, use the Linux release from https://www.azahar-emu.org/pages/download/.

Make a backup of the save file (`Pokemon - Black.sav`) before the first start. Use the save-directory setting of RetroArch or **Import Save**. A `.ml1` file belongs to one emulator and can fail to import. A core change can break save states.

## Other games

Plutonium supports Black Ops 1 and 2, not Black Ops 3. Linux support is unofficial. Follow https://www.plutonium.pw/docs/. Steam games use the Steam installation and the compatibility settings of Steam.

## Scan

After you extract a game, update the ClamAV signatures with `sudo freshclam`. Then run:

```sh
clamscan -r -i "$HOME/Games"
```

A scan during extraction does not cover files that are written later. A clean scan does not prove that a program is safe.
