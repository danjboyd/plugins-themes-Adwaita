# Window tabs (#63)

Taken 2026-10-08, Cantarell 11. Each image is libadwaita 1.7's AdwTabBar on
the left (`Reference/AdwaitaTabBar/adwaita_tab_bar.py --width 652`, a
private Xvfb with no window manager) and the gnustep-window-tabbing
example, TabDemo, under the theme on the right (a private GNOME Shell
session; TabDemo has an in-window menu bar, so its tab bar sits below it).

- `light-reference-theme.png`, `dark-reference-theme.png`: three tabs, the
  first selected. The bar is 40pt in the window's colour (#fafafb,
  #222226); tabs are 34pt, 6pt in from the ends and 5pt apart, sharing the
  width; the selected tab is the foreground at 10% (#e6e6e7, #39393c) with
  a 6pt radius and its close button; 1px separators at 15% sit between
  unselected tabs; the "+" button ends the bar.

Hover (7%, close button shown, neighbouring separators hidden) and high
contrast (a 1px outline at 50%, separators at 50%) are checked by
QuirkProbe's `window-tabs-*` checks rather than shown here.
