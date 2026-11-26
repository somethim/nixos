# The colour keys that the picker (home/shell/Theme.qml) reads, taken from colors.toml.
# colors.toml is the only place where colours are set.
c: {
  bg = c.background;
  bgDark = c.dark_background;
  bgLight = c.lighter_background;
  sel = c.selection;
  fg = c.foreground;
  fgDim = c.dark_foreground;
  muted = c.muted;
  accent = c.cyan;
  accent2 = c.accent;
  inherit (c) red orange yellow green;
}
