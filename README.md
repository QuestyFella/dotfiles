# dotfiles

macOS rice: **AeroSpace** tiling + **SketchyBar** + **JankyBorders**, TUI-style **Hammerspoon** widgets,
and a `theme` command that recolours the whole desktop at once.

![screenshot](screenshots/desktop.png)

| | |
|---|---|
| **OS** | macOS (Apple silicon) |
| **WM** | [AeroSpace](https://github.com/nikitabobko/AeroSpace) |
| **Bar** | [SketchyBar](https://github.com/FelixKratz/SketchyBar) with an Apple-style logo menu and a theme dropdown |
| **Borders** | [JankyBorders](https://github.com/FelixKratz/JankyBorders) |
| **Terminal** | Alacritty · MesloLGS Nerd Font |
| **Shell** | zsh · Oh My Zsh · Powerlevel10k |
| **Editor** | Neovim (LazyVim), Zed |
| **Multiplexer** | Zellij |
| **Widgets** | Hammerspoon webviews · Hack Nerd Font |
| **Palettes** | Catppuccin (all 4) · Nord · Gruvbox dark/light · Tokyo Night + Storm · Rosé Pine · Kanagawa · Dracula · Everforest |

## Theme switcher

```sh
theme                    # fzf picker with a live colour preview
theme tokyo-night        # apply one directly (also: the palette icon in the bar)
theme --wallpaper a.png  # add wallpapers to the current theme
theme --new my-theme     # copy the current palette and edit it
```

One command updates: wallpaper, macOS light/dark mode, Alacritty, iTerm2, SketchyBar, borders,
Neovim (running instances too), Zed, VS Code, Zellij, btop, the widgets, and optionally
Spotify (Spicetify), Discord (Vencord) and Firefox (Pywalfox). Palettes live in
`config/themes/palettes/<name>.sh`.

## Widgets

TUI-style panes that swing in on a 3D hinge and follow the current theme. All toggled with **Hyper** (hold Caps Lock):

| Key | Widget |
|---|---|
| Hyper + M | Music: Spotify cover, progress, controls, like (pops in on track change) |
| Hyper + W | Weather (Open-Meteo, no API key) |
| Hyper + Q | Quote of the day |
| Hyper + R | Todo list (saved in `~/.config/todo.md`) |
| Hyper + P | Pomodoro tied to the todo list, with adjustable durations |
| Hyper + H | System stats (htop-style) |
| Hyper + A | Calendar agenda (needs the helper app, see below) |
| Hyper + G | Wallpaper picker for the current theme |

The full shortcut list is in [`config/SHORTCUTS.md`](config/SHORTCUTS.md) (**Hyper + /** shows it as a floating cheat sheet).

## Install

```sh
git clone https://github.com/QuestyFella/dotfiles ~/dotfiles
cd ~/dotfiles
xcode-select --install       # /usr/bin/python3 + swiftc, used by `theme` and the agenda helper
brew bundle                  # see Brewfile (Alacritty: install from its GitHub releases)
./install.sh --dry-run       # see what it would do
./install.sh                 # existing files are moved to ~/.dotfiles-backup/<time>/
theme catppuccin-mocha
```

Then:

1. **Karabiner-Elements** → Complex Modifications → Add predefined rule → enable the **Rice** rules
   (Caps Lock → Hyper, app shortcuts).
2. `brew services start sketchybar && brew services start borders`
3. Open **AeroSpace** and **Hammerspoon** and give both Accessibility access.
4. Add wallpapers: see [`config/themes/wallpapers/README.md`](config/themes/wallpapers/README.md).

### Why Karabiner *and* AeroSpace?

AeroSpace can only react to shortcuts, not change what a key does, so **Caps Lock → Hyper** (⌃⌥⌘)
has to come from Karabiner. Everything Hyper depends on it. The app shortcuts (Hyper + T, B, D, …) live in
Karabiner too, so they work even when AeroSpace is off or in resize mode. They could move to
AeroSpace's `exec-and-forget` if you prefer. The widget shortcuts are bound in Hammerspoon; they just listen
for ⌃⌥⌘.

Most files are symlinked into place, so `git pull` updates them. `btop.conf`, Zellij's `config.kdl`,
Zed's `settings.json` and the Spicetify theme are copied instead, because `theme` edits them in place.

## Optional extras

**Spotify (Spicetify):**
```sh
spicetify config current_theme Rice color_scheme current extensions hs-bridge.js
spicetify backup apply
```
`hs-bridge.js` lets the music widget like/unlike songs. Spotify updates can undo Spicetify; run `spicetify backup apply` again.

**Firefox:** `pipx install pywalfox && pywalfox install`, then add the Pywalfox extension.
`userChrome.css` loads after a Firefox restart.

**Discord:** install [Vencord](https://vencord.dev). `theme` writes `Vencord/themes/rice.theme.css`;
enable it in Vencord → Themes.

**Agenda widget:** Hammerspoon can't ask for calendar access, so a tiny helper app does it:
```sh
APP=~/Applications/AgendaHelper.app/Contents
mkdir -p $APP/MacOS && cp src/agenda/Info.plist $APP/
swiftc -O src/agenda/main.swift -o $APP/MacOS/agenda-json
codesign -s - --force ~/Applications/AgendaHelper.app
open ~/Applications/AgendaHelper.app --args 1   # allow calendar access when asked
```

## Personal bits you'll probably want to change

- `bin/wireguard-toggle` toggles a WireGuard tunnel named `PC`.
- `bin/easy68k` and `bin/aerospace-wine-fix` run EASy68K under Wine (CrossOver build).
- The Karabiner rules and `bin/*-ws` scripts open my apps (Firefox, Discord, Zed, Spotify, Notes, VS Code).
- `config/nvim` has extras for STM32/Arduino/FPGA, LaTeX and R notes.

## Layout

```
bin/            scripts → ~/.local/bin (theme, cheatsheet, launchers)
config/         → ~/.config (aerospace, sketchybar, borders, alacritty, nvim, zellij, btop, zed, spicetify, themes)
hammerspoon/    → ~/.hammerspoon (widgets.lua + widgets/*.html)
karabiner/      rice.json → Karabiner complex modifications
firefox/        userChrome.css + user.js → your Firefox profile
src/agenda/     calendar helper for the agenda widget
zsh/            .zshrc, .p10k.zsh
```
