# Terminal text effects (Rust port of terminaltexteffects). The screensaver of the desktop
# shell (bin/omarchy-screensaver) runs it. It is not in nixpkgs. Version = the live host.
{ lib, rustPlatform, fetchFromGitHub }:
rustPlatform.buildRustPackage rec {
  pname = "ttfx";
  version = "0.5.0";
  src = fetchFromGitHub {
    owner = "omacom";
    repo = "ttfx";
    rev = "v${version}";
    hash = "sha256-ZeWRyo9zturjRcH23SDgFOKoPOSY6nGMFzGeJAoDapk=";
  };
  cargoHash = "sha256-ntoj5bmAa9U2+3K1UX6HL0t6MjfCYQNe5LuiuNJ/CnY=";

  meta = {
    description = "Terminal text effects, a Rust port of terminaltexteffects";
    homepage = "https://github.com/omacom/ttfx";
    license = lib.licenses.mit;
    mainProgram = "ttfx";
    platforms = lib.platforms.linux;
  };
}
