# Agent skills and agent settings (Claude Code, Codex).
#
# The skills come from GitHub (somethim-omarchy/agent-skills, the flake input `agent-skills`).
# Each skill folder in its skills/ and vendor/ is linked from the store to ~/.claude/skills/<name>
# (Claude Code) and ~/.agents/skills/<name> (Codex). The links are read-only: change a skill in its
# own repository, push it, then run `nix flake update agent-skills` and rebuild. Other entries in
# those folders (synced skills, plugin skills) stay untouched, because the links are per skill.
{ config, lib, inputs, btopConfigCheckout, ... }:
let
  checkoutName = if btopConfigCheckout == null then "Work/nixos-config" else btopConfigCheckout;
  checkout = "${config.home.homeDirectory}/${checkoutName}/home";
  link = path: config.lib.file.mkOutOfStoreSymlink "${checkout}/${path}";

  skills = lib.concatMap
    (group: map (name: "${group}/${name}")
      (lib.attrNames (lib.filterAttrs (_: type: type == "directory")
        (builtins.readDir "${inputs.agent-skills}/${group}"))))
    [ "skills" "vendor" ];
  deploy = base: lib.listToAttrs (map
    (path: lib.nameValuePair "${base}/${baseNameOf path}" { source = "${inputs.agent-skills}/${path}"; })
    skills);
in
{
  home.file = deploy ".claude/skills" // deploy ".agents/skills" // {
    # The agents write to these files: linked to the checkout, not to the store.
    ".claude/CLAUDE.md".source = link "config/claude/CLAUDE.md";
    ".claude/settings.json".source = link "config/claude/settings.json";
    ".claude/scripts/statusline.sh".source = link "config/claude/scripts/statusline.sh";
    ".codex/AGENTS.md".source = link "config/codex/AGENTS.md";
    # Hooks that herdr (agent state in the herdr tab list) generated; read-only copies from the store.
    # To refresh them after a herdr update, copy the new files over the ones in home/config/ (README section 10).
    ".claude/hooks/herdr-agent-state.sh" = { source = ./config/claude/hooks/herdr-agent-state.sh; executable = true; };
    ".codex/herdr-agent-state.sh" = { source = ./config/codex/herdr-agent-state.sh; executable = true; };
    ".codex/hooks.json".source = ./config/codex/hooks.json;
    # Text for the screensaver.
    ".config/omarchy/branding/screensaver.txt".source = ./config/branding/screensaver.txt;
  };
}
