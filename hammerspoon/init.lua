-- Hammerspoon config
hs.autoLaunch(true)
hs.menuIcon(false)        -- no menu bar icon (SketchyBar replaces the menu bar)
hs.dockIcon(false)

require("hs.ipc")      -- lets `hs -c ...` drive this from a terminal
widgets = require("widgets") -- global so it stays alive (and is reachable from the console)
widgets.start()
