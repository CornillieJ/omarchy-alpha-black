# Alpha Black

An [Omarchy](https://omarchy.org) plugin that makes black (or any color you
pick) in a window see-through, so a terminal, a video player's letterbox or a
dark-themed app floats over your wallpaper and the windows behind it.

Run it once on the focused window to turn it on. An editor pops up so you can
tune it live while you watch the window change:

- **Red / Green / Blue**: the color that becomes transparent (black by default)
- **Tolerance**: how close a pixel has to be to that color to be affected.
  Near-matches fade out gradually, so antialiased text keeps clean edges.
- **Glass**: blur what shows through, for a frosted/acrylic look instead of a
  clear cutout
- **Frost** (with Glass on): how much of the color stays over the blur, from
  0 (pure blurred glass) to 0.9 (mostly opaque, tinted acrylic). Blur strength
  itself is Hyprland's global `decoration.blur` setting; Hyprland has no
  per-window blur size.
- **Pick from screen** (`P`): grab the color with hyprpicker

Press Enter (or Escape) to close the editor and keep the settings. Running it
again on the same window turns it off; turning it back on reopens the editor
with that window's last settings.

## Install

```bash
omarchy plugin add https://github.com/CornillieJ/omarchy-alpha-black.git --enable
```

## Requirements

The transparency itself is done by the
[Hypr-DarkWindow](https://github.com/micha4w/Hypr-DarkWindow) Hyprland plugin.
You don't need to install it: the first time you use Alpha Black (and again
after a Hyprland update), it clones Hypr-DarkWindow into
`~/.local/share/hypr-darkwindow`, checks out the commit pinned for your
Hyprland version and builds it. That needs `git`, `make`, `g++`,
`pkg-config` and the Hyprland development headers, which come with Omarchy's
`hyprland` package. Hypr-DarkWindow is loaded into Hyprland on first use only,
never from your Hyprland config, so it can't break your session at login.

`hyprpicker` (shipped with Omarchy) is used for Pick from screen.

## Remove

```bash
omarchy plugin remove jeffrey.alpha-black
```

## Use

Enabling the plugin adds an "Alpha Black" entry to the Omarchy menu (under
Trigger) automatically. It does this once, by adding a `trigger.alphablack`
row to `~/.config/omarchy/extensions/omarchy-menu.jsonc` the first time it
loads:

```jsonc
"trigger.alphablack": {
  "icon": "󰈈",
  "label": "Alpha Black",
  "aliases": ["alphablack", "alpha black", "transparent black", "chromakey"],
  "description": "Toggle: make a color in the focused window transparent",
  "action": "$HOME/.config/omarchy/plugins/jeffrey.alpha-black/alpha-black"
}
```

It only does this if that key isn't already there, so hand edits stick.
Delete the block if you don't want the menu entry; it won't come back unless
you remove the plugin and add it again.

Prefer a keybinding instead (`~/.config/hypr/bindings.lua`)?

```lua
o.bind(hyper .. "B", "Alpha Black", "~/.config/omarchy/plugins/jeffrey.alpha-black/alpha-black")
```

Settings are remembered per window until you log out.

## License

MIT
