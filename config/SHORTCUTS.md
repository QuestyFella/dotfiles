# My Mac Setup — Shortcuts & Config

**Hyper** = hold **Caps Lock** (acts as ⌃⌥⌘). Tap Caps Lock alone → normal Caps Lock.
Toggle this sheet: **Hyper + /** · close with **q**

---

## App launchers (Karabiner)

| Keys | Does |
|---|---|
| Hyper + T | New Alacritty window (opens Alacritty if closed) |
| Hyper + F | Alacritty in the front Finder window's folder |
| Hyper + C | VS Code in the front Finder window's folder |
| Hyper + B | Firefox |
| Hyper + D | Discord (on workspace D) |
| Hyper + N | Apple Notes |
| Hyper + Z | Zed |
| Hyper + V | Toggle WireGuard `PC` tunnel |
| Hyper + E | EASy68K (jumps to workspace E, starts it if needed) |
| Hyper + S | Spotify (on workspace S) |
| Hyper + / | This cheat sheet |
| Hyper + M | Music widget (Spotify) — also pops in by itself on track change |
| Hyper + L | Like / unlike the current Spotify song (flashes the music widget) |
| Hyper + W | Weather widget |
| Hyper + Q | Quote of the day — also pops in once a day on unlock; click [ ↻ ] for a new one |
| Hyper + A | Agenda — next 7 days from Google + iCloud calendars, live countdown; click an event → Google Calendar. Pops in 10 min before events |
| Hyper + P | Pomodoro — pick a todo, 25 min focus / 5 break (15 every 4th); asks to tick the task off; countdown shows in the bar. [ ⚙ ] = change durations + reset all (new set, 0 done) |
| Hyper + H | System stats (htop-style): per-core CPU, mem, swap, disk, battery, net, load, top processes |
| Hyper + G | Wallpaper picker — thumbnails of the current theme's wallpapers; ←↑↓→ / hjkl + ⏎ (or click) to set, stays open so you can try several; esc closes |
| Hyper + R | Todo list — type ⏎ to add · ↑↓ select · ␣ toggle · ⌫ delete · esc close (saved in `~/.config/todo.md`) |

Free Hyper keys: I J K O U X Y, numbers

**EASy68K (Wine):** everything lives on workspace E. Editor, Simulator and I/O tile; Hardware
and dialogs float. Wine windows are only picked up once clicked — click a new simulator
window once and it snaps into place. No focus border on Wine windows (JankyBorders limitation).

---

## Windows (AeroSpace)

| Keys | Does |
|---|---|
| ⌃ H / J / K / L | Focus window left / down / up / right |
| ⌃⇧ H / J / K / L | Move window left / down / up / right |
| ⌃⇧ ← ↓ ↑ → | Join with window in that direction |
| ⌥ F | Fullscreen |
| ⌥ X | Close window |
| ⌥ / | Tiles layout (toggle horizontal / vertical) |
| ⌥ , | Accordion layout (toggle horizontal / vertical) |
| ⌥ R | Resize mode |
| ⌥⇧ ; | Service mode |
| ⌥ ↵ | New Terminal.app window |
| ⌃⌥ N | New iTerm2 window |

## Workspaces (AeroSpace)

| Keys | Does |
|---|---|
| ⌥ 1 – 9 | Go to workspace 1 – 9 |
| ⌥ B D E J S T W V Y | Go to that lettered workspace |
| ⌥⇧ + number / letter | Move window to that workspace |
| ⌥ Tab | Back to previous workspace |
| ⌥⇧ Tab | Move workspace to next monitor |

### Resize mode (after ⌥ R)

| Keys | Does |
|---|---|
| H / L | Narrower / wider |
| J / K | Taller / shorter |
| ⇧ + H J K L | Same, bigger steps |
| − / = | Shrink / grow (smart) |
| B | Balance sizes |
| Esc / ↵ | Back to normal |

### Service mode (after ⌥⇧ ;)

| Keys | Does |
|---|---|
| Esc | Reload AeroSpace config |
| R | Flatten (reset) layout |
| F | Toggle floating / tiling |
| ⌫ | Close all windows except current |
| ⌥⇧ H / J / K / L | Join with window in that direction |

---

## Bar (SketchyBar, click)

| Item | Does |
|---|---|
| Workspace number | Go to that workspace |
| ⏱ countdown (when a pomodoro is running) | Open the pomodoro widget |
| Logo (left) | Apple-style menu: About, System Settings, Activity Monitor, Shortcuts, Sleep, Lock, Restart…, Shut Down…, Log Out… (… = asks to confirm) |
| 🎨 Palette icon | Theme dropdown — pick a theme |
| VPN item | Toggle WireGuard `PC` |

---

## Themes

| Command | Does |
|---|---|
| `theme` | Picker with colour preview (fzf) |
| `theme <name>` | Switch directly, e.g. `theme nord` |
| `theme --list` | List themes |
| `theme --current` | Show active theme |
| `theme --wallpaper <img…>` | Add image(s) to the current theme and show one |
| `theme --next-wallpaper` | Switch to another of the current theme's wallpapers |
| `theme --new <name> [from]` | New theme copied from `[from]` (default: current), opens to edit |

Themes: catppuccin-mocha · catppuccin-macchiato · catppuccin-frappe · catppuccin-latte ·
nord · gruvbox-dark · gruvbox-light · tokyo-night · tokyo-night-storm · rose-pine ·
kanagawa · dracula · everforest

Switching changes: wallpaper, macOS light/dark, Alacritty, SketchyBar, window borders,
Neovim (live), Zed, Zellij, iTerm2 (live), VS Code (live), Discord (live, via Vencord),
Firefox (live, via Pywalfox), Spotify (Spicetify — restarts Spotify unless music is playing,
then applies next launch), btop (on next launch). Dracula & Everforest skip Zed.

- **New theme:** `theme --new <name>` (or copy a file in `~/.config/themes/palettes/`), edit the hex values.
- **Own wallpapers:** put any images in `~/.config/themes/wallpapers/<theme-name>/` — one is picked at random
  on each switch. Generated gradients (`wallpapers/generated/`) are only used when that folder is empty.

---

## Watch out

- ⌃ H/J/K/L are taken by AeroSpace everywhere → ⌃L (clear) / ⌃K don't reach the terminal or Neovim.
- ⌥ + letter workspaces block typing Option characters (∫ ∂ …).
- Rectangle (⌃⌥ + arrows / U I J K / D F G / E T / ↵) fights AeroSpace on tiled windows.

---

## Where things live

| What | Path |
|---|---|
| Hotkeys (Karabiner) | `~/.config/karabiner/karabiner.json` |
| Tiling (AeroSpace) | `~/.config/aerospace/aerospace.toml` |
| Bar (SketchyBar) | `~/.config/sketchybar/` (`sketchybarrc`, `plugins/`) |
| Window borders | `~/.config/borders/bordersrc` |
| Theme palettes | `~/.config/themes/palettes/` |
| Wallpapers | `~/.config/themes/wallpapers/` |
| Theme switcher | `~/.local/bin/theme` |
| Alacritty | `~/.config/alacritty/alacritty.toml` (+ generated `theme.toml`) |
| Neovim theme hook | `~/.config/nvim/lua/plugins/theme.lua` |
| Hotkey scripts | `~/.local/bin/` — `alacritty-new-window`, `alacritty-here`, `vscode-here`, `wireguard-toggle`, `cheatsheet` |
| Hotkey log | `/tmp/alacritty-new-window.log` |
| Calendar reader | `~/Applications/AgendaHelper.app` (source `~/.local/src/agenda/main.swift`) |
| Widgets (Hammerspoon) | `~/.hammerspoon/widgets.lua` + `~/.hammerspoon/widgets/*.html` |
| This sheet | `~/.config/SHORTCUTS.md` |

Backups: `alacritty.toml.bak`, `aerospace.toml.bak`, `karabiner.json.bak` (next to the originals).

Restart things: `brew services restart sketchybar` · `brew services restart borders` · AeroSpace: ⌥⇧ ; then Esc
