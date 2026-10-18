-- Animated pop-in widgets (music / weather / quote), themed by ~/.local/bin/theme.
-- Each widget is a transparent, borderless webview (widgets/<name>.html). Lua fetches the
-- data and pushes it in with JS calls; the page handles all animation.
--   Hyper (⌃⌥⌘) + M / W / Q / R  toggle music / weather / quote / todo
--   Hyper + A  agenda (Google/iCloud calendars via ~/Applications/AgendaHelper.app); pops in 10 min before events
--   Hyper + P / H  pomodoro (tied to the todo list) / system stats (htop-ish)
--   Hyper + G  wallpaper picker for the current theme (thumbnail grid; arrows/hjkl + ⏎, or click)
--   Hyper + L  like/unlike the current Spotify song (via the Spicetify extension hs-bridge.js)
--   Todo items live in ~/.config/todo.md ("- [ ] task" lines), editable from anywhere.
--   Music pops in on its own when the Spotify track changes; quote once per day on unlock.
local M = {}

local HYPER = { "ctrl", "alt", "cmd" }
local DIR = hs.configdir .. "/widgets/"
local THEME_DIR = os.getenv("HOME") .. "/.config/themes/current"
local BAR = 44 -- SketchyBar height + gap

local widgets = {}

-- ── Theme ────────────────────────────────────────────────────────────────────
local function readPalette()
  local f = io.open(THEME_DIR .. "/palette.sh")
  if not f then return {} end
  local s = f:read("a")
  f:close()
  local p = {}
  for k, v in s:gmatch("([%u%d_]+)=(%x%x%x%x%x%x)%f[^%x]") do p[k] = v end
  for k, ref in s:gmatch("([%u_]+)=%$([%u%d_]+)") do p[k] = p[k] or p[ref] end
  p.MODE = s:match('THEME_MODE="(%a+)"') or "dark"
  return p
end

-- ── Webview plumbing ─────────────────────────────────────────────────────────
local function js(w, code)
  if w.ready then w.wv:evaluateJavaScript(code) else table.insert(w.queue, code) end
end

local function call(name, fn, arg)
  local w = widgets[name]
  -- hs.json.encode only takes tables, so wrap the arg in an array and strip the brackets
  if w then js(w, string.format("%s(%s)", fn, arg ~= nil and hs.json.encode({ arg }):sub(2, -2) or "")) end
end

local function pushTheme(w) js(w, "setTheme(" .. hs.json.encode(readPalette()) .. ")") end

local function make(name, frameFn, opts)
  local w = { name = name, frameFn = frameFn, opts = opts or {}, ready = false, queue = {}, visible = false }
  local uc = hs.webview.usercontent.new("hs")
  uc:setCallback(function(msg)
    local body = msg.body or {}
    if body.action == "hide" then M.hide(name)
    elseif w.opts.onMessage then w.opts.onMessage(body) end
  end)
  w.wv = hs.webview.new(frameFn(), { developerExtrasEnabled = false }, uc)
    :windowStyle({ "borderless", "nonactivating" })
    :transparent(true)
    :shadow(false)
    :allowTextEntry(w.opts.textEntry or false)
    :level(hs.drawing.windowLevels.floating)
    :behavior(hs.drawing.windowBehaviors.canJoinAllSpaces)
    :navigationCallback(function(action)
      if action == "didFinishNavigation" then
        w.ready = true
        pushTheme(w)
        for _, code in ipairs(w.queue) do w.wv:evaluateJavaScript(code) end
        w.queue = {}
      end
    end)
  w.wv:url("file://" .. DIR .. name .. ".html")
  widgets[name] = w
  return w
end

function M.show(name, seconds)
  local w = widgets[name]
  if w.hideTimer then w.hideTimer:stop(); w.hideTimer = nil end
  if w.goneTimer then w.goneTimer:stop(); w.goneTimer = nil end
  if not w.visible then
    w.wv:frame(w.frameFn())
    w.wv:show()
    js(w, "enter()")
    w.visible = true
    if w.opts.onShow then w.opts.onShow() end
  end
  if seconds then w.hideTimer = hs.timer.doAfter(seconds, function() M.hide(name) end) end
end

function M.hide(name)
  local w = widgets[name]
  if not w.visible then return end
  w.visible = false
  w.pinned = false
  if w.hideTimer then w.hideTimer:stop(); w.hideTimer = nil end
  if w.opts.onHide then w.opts.onHide() end
  js(w, "leave()")
  w.goneTimer = hs.timer.doAfter(0.55, function() w.wv:hide(); w.goneTimer = nil end)
end

-- Opened by hotkey → stays until toggled off (pinned); auto pop-ups hide themselves.
function M.toggle(name)
  local w = widgets[name]
  if w.visible then M.hide(name) else w.pinned = true; M.show(name) end
end

-- Screen geometry (main screen, points)
local function scr() return hs.screen.mainScreen():fullFrame() end

-- ── Music (Spotify) ──────────────────────────────────────────────────────────
-- "is running" check first: a bare `tell application` would relaunch Spotify if it
-- quit between our check and the query (e.g. you quit it, or a theme-switch restart).
local SPOTIFY_SCRIPT = [[
if application "Spotify" is not running then return ""
tell application "Spotify"
  set t to current track
  return (name of t) & "|||" & (artist of t) & "|||" & (album of t) & "|||" & (artwork url of t) & "|||" & (duration of t) & "|||" & (player position) & "|||" & (player state as string)
end tell]]

-- Asks Spotify via a separate osascript process: an in-process AppleScript call would
-- freeze all of Hammerspoon whenever Spotify is slow to answer (e.g. while restarting).
local spotifyTask
local function spotifyState(cb)
  if not hs.application.get("com.spotify.client") then cb({ running = false }); return end
  if spotifyTask and spotifyTask:isRunning() then return end
  local task
  task = hs.task.new("/usr/bin/osascript", function(code, out)
    if code ~= 0 or not out or out == "" then return end -- transient failure: keep showing the last state
    local f = {}
    for part in (out:gsub("\n$", "") .. "|||"):gmatch("(.-)|||") do table.insert(f, part) end
    cb({ running = true, title = f[1], artist = f[2], album = f[3], art = f[4],
         duration = (tonumber(f[5]) or 0) / 1000, position = tonumber(f[6]) or 0,
         playing = f[7] == "playing" })
  end, { "-e", SPOTIFY_SCRIPT })
  spotifyTask = task
  task:start()
  -- kill only this query if Spotify never answers (not whichever query is current by then)
  hs.timer.doAfter(3, function() if task:isRunning() then task:terminate() end end)
end

-- Liked state comes from the Spicetify extension ~/.config/spicetify/Extensions/hs-bridge.js,
-- which connects to this local websocket (reports every 5s, so "connected" = heard lately).
local heart = { liked = false, at = 0 }
local function bridgeUp() return os.time() - heart.at < 12 end

local musicTimer
local function pushMusic()
  spotifyState(function(s)
    s.liked, s.bridge = heart.liked, bridgeUp()
    call("music", "update", s)
  end)
end

M.bridge = hs.httpserver.new(false, false)
  :setInterface("localhost"):setPort(7655)
  :setCallback(function() return "hs-bridge", 200, {} end)
  :websocket("/spotify", function(msg)
    local m = hs.json.decode(msg or "")
    if m and m.type == "heart" then
      heart = { liked = m.liked, uri = m.uri, at = os.time() }
      call("music", "heart", { liked = m.liked, bridge = true })
    end
    return ""
  end)
  :start()

function M.like()
  if not bridgeUp() then
    hs.alert.show("♡ like needs the Spicetify hs-bridge extension (restart Spotify)")
    return
  end
  M.bridge:send("toggle")
end

-- ── Weather (IP location → Open-Meteo, no API key) ──────────────────────────
local weather = { at = 0 }
local function fetchWeather()
  if os.time() - weather.at < 600 and weather.data then call("weather", "update", weather.data); return end
  hs.http.asyncGet("https://ipapi.co/json/", nil, function(code, body)
    local loc = code == 200 and hs.json.decode(body) or nil
    if not (loc and loc.latitude) then call("weather", "failed", "Couldn't find your location"); return end
    local f = loc.country_code == "US" and "&temperature_unit=fahrenheit&wind_speed_unit=mph" or ""
    local url = string.format("https://api.open-meteo.com/v1/forecast?latitude=%s&longitude=%s"
      .. "&current=temperature_2m,apparent_temperature,weather_code,wind_speed_10m,relative_humidity_2m,is_day"
      .. "&hourly=temperature_2m,weather_code,is_day&forecast_hours=7&timezone=auto%s", loc.latitude, loc.longitude, f)
    hs.http.asyncGet(url, nil, function(c2, b2)
      local wx = c2 == 200 and hs.json.decode(b2) or nil
      if not wx then call("weather", "failed", "Weather service unreachable"); return end
      wx.city = loc.city
      weather = { at = os.time(), data = wx }
      call("weather", "update", wx)
    end)
  end)
end

-- ── Quote of the day (ZenQuotes, cached per day) ─────────────────────────────
local FALLBACK_QUOTES = {
  { q = "Simplicity is prerequisite for reliability.", a = "Edsger W. Dijkstra" },
  { q = "The best way to predict the future is to invent it.", a = "Alan Kay" },
  { q = "Make it work, make it right, make it fast.", a = "Kent Beck" },
  { q = "Stay hungry, stay foolish.", a = "Stewart Brand" },
}
local function today() return os.date("%Y-%m-%d") end

local function fetchQuote(cb)
  local cached = hs.settings.get("widgets.quote")
  if cached and cached.date == today() then cb(cached); return end
  hs.http.asyncGet("https://zenquotes.io/api/today", nil, function(code, body)
    local r = code == 200 and hs.json.decode(body) or nil
    local q = (r and r[1] and r[1].q) and { q = r[1].q, a = r[1].a }
              or FALLBACK_QUOTES[(os.date("*t").yday % #FALLBACK_QUOTES) + 1]
    q.date = today()
    hs.settings.set("widgets.quote", q)
    cb(q)
  end)
end

-- Refresh button: a random quote (ZenQuotes, else a different built-in one) becomes today's quote.
local function refreshQuote()
  M.show("quote") -- cancels any auto-hide while you browse quotes
  local current = (hs.settings.get("widgets.quote") or {}).q
  local done = false
  local function use(q)
    if done then return end
    done = true
    if not q or q.q == current then
      local pool = hs.fnutils.filter(FALLBACK_QUOTES, function(f) return f.q ~= current end)
      q = hs.fnutils.copy(pool[math.random(#pool)])
    end
    q.date = today()
    hs.settings.set("widgets.quote", q)
    call("quote", "update", q)
    call("quote", "retype")
  end
  hs.http.asyncGet("https://zenquotes.io/api/random", nil, function(code, body)
    local r = code == 200 and hs.json.decode(body) or nil
    use(r and r[1] and r[1].q and { q = r[1].q, a = r[1].a })
  end)
  hs.timer.doAfter(4, function() use(nil) end) -- slow/offline: built-in quote instead
end

local function showQuote(seconds)
  fetchQuote(function(q) call("quote", "update", q); M.show("quote", seconds) end)
end
M.showQuote = showQuote

-- ── Todo (~/.config/todo.md, markdown checklist) ─────────────────────────────
local TODO_FILE = os.getenv("HOME") .. "/.config/todo.md"
local lastTodoWrite = 0

local function readTodos()
  local items, f = {}, io.open(TODO_FILE)
  if not f then return items end
  for line in f:lines() do
    local mark, text = line:match("^%s*[-*] %[([ xX])%]%s+(.+)$")
    if mark then table.insert(items, { text = text, done = mark ~= " " }) end
  end
  f:close()
  return items
end

local function writeTodos(items)
  local out = { "# todo", "" }
  for _, it in ipairs(items) do table.insert(out, string.format("- [%s] %s", it.done and "x" or " ", it.text)) end
  local f = io.open(TODO_FILE, "w")
  f:write(table.concat(out, "\n") .. "\n")
  f:close()
  lastTodoWrite = hs.timer.secondsSinceEpoch()
end

-- ── Pomodoro (tied to the todo list) ─────────────────────────────────────────
-- Timer state lives here (keeps running while the widget is hidden). Focus sessions can be
-- attached to an open todo; when one ends you're asked if it's done → ticks it in todo.md.
local POMO = { focus = 25 * 60, short = 5 * 60, long = 15 * 60, every = 4 }
for k, v in pairs(hs.settings.get("widgets.pomoDurations") or {}) do POMO[k] = math.floor(v) end -- set from the ⚙ panel (floor: keep ints)
-- ⚙ panel steppers: { min, max, step } (minutes for durations, sessions for `every`)
local POMO_LIMITS = { focus = { 5, 90, 5 }, short = { 1, 30, 1 }, long = { 5, 60, 5 }, every = { 2, 8, 1 } }
local pomo = { phase = "focus", running = false, left = POMO.focus, sessions = 0, task = nil, ask = false }
local pomoTimer

local function phaseLength(ph) return ph == "focus" and POMO.focus or ph == "long" and POMO.long or POMO.short end

local function openTasks()
  local out = {}
  for _, it in ipairs(readTodos()) do if not it.done then table.insert(out, it.text) end end
  return out
end

local function pomoBar()
  local args
  if pomo.phase == "focus" and not pomo.running and pomo.left == POMO.focus then
    args = { "--set", "pomo", "drawing=off" }
  else
    local icon = utf8.char(pomo.running and (pomo.phase == "focus" and 0xF051B or 0xF0176) or 0xF03E4) -- timer / coffee / pause
    args = { "--set", "pomo", "drawing=on", "icon=" .. icon,
             string.format("label=%02d:%02d", pomo.left // 60, pomo.left % 60) }
  end
  hs.task.new("/opt/homebrew/bin/sketchybar", nil, args):start()
end

local function pomoPush()
  call("pomo", "update", { phase = pomo.phase, running = pomo.running, left = pomo.left,
    total = phaseLength(pomo.phase), sessions = pomo.sessions, every = POMO.every,
    durations = { focus = POMO.focus // 60, short = POMO.short // 60, long = POMO.long // 60 },
    task = pomo.task, ask = pomo.ask, tasks = openTasks() })
  pomoBar()
end

local function pomoStop() if pomoTimer then pomoTimer:stop(); pomoTimer = nil end; pomo.running = false end

local function pomoFinish()
  pomoStop()
  if pomo.phase == "focus" then
    pomo.sessions = pomo.sessions + 1
    pomo.ask = pomo.task ~= nil
    pomo.phase = (pomo.sessions % POMO.every == 0) and "long" or "short"
    hs.notify.new({ title = "Focus session done 🍅", informativeText = (pomo.task and ("“" .. pomo.task .. "” — ") or "")
      .. (pomo.phase == "long" and "take a long break" or "take a short break"), withdrawAfter = 8 }):send()
  else
    pomo.phase = "focus"
    hs.notify.new({ title = "Break's over", informativeText = "Ready for the next focus session?", withdrawAfter = 8 }):send()
  end
  pomo.left = phaseLength(pomo.phase)
  local snd = hs.sound.getByName("Glass"); if snd then snd:play() end
  widgets.pomo.pinned = true
  M.show("pomo")
  if pomo.phase ~= "focus" then M.pomoAction({ action = "start" }) else pomoPush() end
end

local function pomoTick()
  pomo.left = math.max(0, math.floor(pomo.endsAt - hs.timer.secondsSinceEpoch() + 0.5))
  if pomo.left <= 0 then pomoFinish() else pomoPush() end
end

function M.pomoAction(m)
  local a = m.action
  if a == "start" and not pomo.running then
    pomo.running = true
    pomo.endsAt = hs.timer.secondsSinceEpoch() + pomo.left
    pomoTimer = hs.timer.doEvery(1, pomoTick)
  elseif a == "pause" then pomoStop()
  elseif a == "reset" then pomoStop(); pomo.left = phaseLength(pomo.phase)
  elseif a == "skip" then pomo.left = 0; pomo.endsAt = 0; pomo.running = true; pomoFinish(); return
  elseif a == "resetAll" then -- back to a fresh set: focus, 0 sessions (keeps the picked task)
    pomoStop()
    pomo.phase, pomo.sessions, pomo.ask = "focus", 0, false
    pomo.left = POMO.focus
  elseif a == "set" and POMO_LIMITS[m.key] then
    local lim, k = POMO_LIMITS[m.key], m.key
    local unit = k == "every" and 1 or 60
    local fresh = not pomo.running and pomo.left == phaseLength(pomo.phase) -- untouched timer follows the change
    POMO[k] = math.max(lim[1], math.min(lim[2], POMO[k] // unit + (m.dir or 0) * lim[3])) * unit
    hs.settings.set("widgets.pomoDurations", { focus = POMO.focus, short = POMO.short, long = POMO.long, every = POMO.every })
    if fresh then pomo.left = phaseLength(pomo.phase) end
  elseif a == "pick" then pomo.task = m.task
  elseif a == "done" or a == "keep" then
    if a == "done" and pomo.task then
      local items = readTodos()
      for _, it in ipairs(items) do if it.text == pomo.task and not it.done then it.done = true; break end end
      writeTodos(items)
      call("todo", "update", items)
      pomo.task = nil
    end
    pomo.ask = false
  end
  pomoPush()
end

-- ── System stats (htop-ish) ──────────────────────────────────────────────────
local STATS_SH = [[
sysctl -n vm.swapusage; sysctl -n vm.loadavg; sysctl -n kern.boottime
echo "--df"; df -k /System/Volumes/Data | tail -1  # "/" is just the sealed system volume
echo "--net"; netstat -ibn | awk '$1 ~ /^en[0-9]+$/ && $3 ~ /Link/ {i+=$7; o+=$10} END {print i, o}'
echo "--ps"; ps -Aceo pid=,pcpu=,rss=,comm= -r | head -7
]]
local statsTimer, statsTask, lastNet

local function collectStats()
  if statsTask and statsTask:isRunning() then return end
  local data = {}
  hs.host.cpuUsage(0.5, function(u)
    data.cores = {}
    for i = 1, u.n do data.cores[i] = u[i].active end
    data.cpu = u.overall.active
  end)
  local vm = hs.host.vmStat()
  data.memTotal = vm.memSize
  data.memUsed = (vm.pagesActive + vm.pagesWiredDown + vm.pagesUsedByVMCompressor) * vm.pageSize
  data.battery = { pct = hs.battery.percentage(), charging = hs.battery.isCharging(),
                   plugged = hs.battery.powerSource() == "AC Power", mins = hs.battery.timeRemaining() }
  statsTask = hs.task.new("/bin/sh", function(_, out)
    local sec = "head"
    data.procs = {}
    for line in (out or ""):gmatch("[^\n]+") do
      if line:sub(1, 2) == "--" then sec = line:sub(3)
      elseif sec == "head" then
        local tot, used = line:match("total = ([%d.]+)M%s+used = ([%d.]+)M")
        if tot then data.swapTotal, data.swapUsed = tonumber(tot) * 2^20, tonumber(used) * 2^20 end
        local l1, l5, l15 = line:match("^{ ([%d.]+) ([%d.]+) ([%d.]+) }")
        if l1 then data.load = { tonumber(l1), tonumber(l5), tonumber(l15) } end
        local boot = line:match("sec = (%d+)")
        if boot then data.uptime = os.time() - tonumber(boot) end
      elseif sec == "df" then
        local size, used = line:match("^%S+%s+(%d+)%s+(%d+)")
        if size then data.diskTotal, data.diskUsed = tonumber(size) * 1024, tonumber(used) * 1024 end
      elseif sec == "net" then
        local i, o = line:match("(%d+) (%d+)")
        local now = hs.timer.secondsSinceEpoch()
        if i then
          i, o = tonumber(i), tonumber(o)
          if lastNet then data.netDown = (i - lastNet.i) / (now - lastNet.t); data.netUp = (o - lastNet.o) / (now - lastNet.t) end
          lastNet = { i = i, o = o, t = now }
        end
      elseif sec == "ps" then
        local pid, cpu, rss, cmd = line:match("^%s*(%d+)%s+([%d.]+)%s+(%d+)%s+(.+)$")
        if pid then table.insert(data.procs, { pid = pid, cpu = tonumber(cpu), mem = tonumber(rss) * 1024, cmd = cmd }) end
      end
    end
    -- cpuUsage samples for 0.5s; wait for it if the shell was quicker
    local function send() if data.cpu then call("stats", "update", data) else hs.timer.doAfter(0.2, send) end end
    send()
  end, { "-c", STATS_SH })
  statsTask:start()
end

-- ── Agenda (macOS Calendar store, incl. synced Google calendars) ────────────
-- ~/Applications/AgendaHelper.app (Swift/EventKit, source ~/.local/src/agenda) has its own
-- calendar permission — Hammerspoon's bundle can't request one — and prints JSON to stdout.
local AGENDA_APP = os.getenv("HOME") .. "/Applications/AgendaHelper.app"
local AGENDA_OUT = os.getenv("TMPDIR") .. "agenda.json"
local agenda = { events = {}, synced = 0 }
local agendaTask
local remindedFor = {}

local function fetchAgenda(cb)
  if agendaTask and agendaTask:isRunning() then return end
  os.remove(AGENDA_OUT) -- `open --stdout` appends, so stale runs would pile up into invalid JSON
  agendaTask = hs.task.new("/usr/bin/open", function(code)
    local f = io.open(AGENDA_OUT)
    local d = f and hs.json.decode(f:read("a")); if f then f:close() end
    if not d or d.error then
      call("agenda", "failed", d and d.error == "no-access" and "no calendar access — allow Agenda Helper in System Settings → Privacy → Calendars" or "couldn't read calendars")
      return
    end
    local seen, events = {}, {}
    for _, e in ipairs(d.events or {}) do -- holiday calendars appear under several accounts
      local key = e.title .. "|" .. e.start
      if not seen[key] then seen[key] = true; table.insert(events, e) end
    end
    agenda = { events = events, synced = os.time() }
    call("agenda", "update", agenda)
    if cb then cb() end
  end, { "-g", "-W", "--stdout", AGENDA_OUT, AGENDA_APP, "--args", "7" })
  agendaTask:start()
end

-- Pop the agenda in ~10 minutes before an event starts
local function checkReminders()
  local now = os.time()
  for _, e in ipairs(agenda.events) do
    if not e.allDay then
      local y, mo, d, h, mi, sec = e.start:match("(%d+)-(%d+)-(%d+)T(%d+):(%d+):(%d+)Z")
      if y then
        local t = os.time({ year = y, month = mo, day = d, hour = h, min = mi, sec = sec, isdst = false })
        t = t + (os.time() - os.time(os.date("!*t"))) -- fields were UTC: shift by the (isdst=false) offset
        local key = e.title .. e.start
        if t - now <= 600 and t - now > 0 and not remindedFor[key] then
          remindedFor[key] = true
          call("agenda", "update", agenda)
          M.show("agenda", 20)
          hs.notify.new({ title = "Starting in " .. math.ceil((t - now) / 60) .. " min", informativeText = e.title, withdrawAfter = 10 }):send()
        end
      end
    end
  end
end

-- ── Wallpaper picker (current theme's images; applied via `theme --set-wallpaper`) ──
local WP_DIR = os.getenv("HOME") .. "/.config/themes/wallpapers/"
local THUMBS = os.getenv("HOME") .. "/.cache/wallpaper-thumbs/"
local WP_EXT = { png = true, jpg = true, jpeg = true, heic = true, webp = true }
local wp = { items = {} }

local function readFile(path)
  local f = io.open(path, "rb"); if not f then return nil end
  local s = f:read("a"); f:close(); return s
end

-- same lookup order as the theme script: wallpapers/<name>/*, wallpapers/<name>.<ext>, generated/<name>.png
local function wallpaperList(name)
  local list = {}
  local dir = WP_DIR .. name
  if hs.fs.attributes(dir, "mode") == "directory" then
    for f in hs.fs.dir(dir) do
      local ext = f:match("%.(%w+)$")
      if ext and WP_EXT[ext:lower()] and f:sub(1, 1) ~= "." then table.insert(list, dir .. "/" .. f) end
    end
    table.sort(list)
  end
  for ext in pairs(WP_EXT) do
    if hs.fs.attributes(WP_DIR .. name .. "." .. ext) then table.insert(list, WP_DIR .. name .. "." .. ext) end
  end
  local gen = WP_DIR .. "generated/" .. name .. ".png"
  if #list == 0 and hs.fs.attributes(gen) then table.insert(list, gen) end
  return list
end

-- Thumbnails are cached (keyed on path + mtime) and made one at a time with sips, off the main thread.
local function loadThumbs(gen)
  hs.fs.mkdir(THUMBS)
  local i = 0
  local function nextThumb()
    i = i + 1
    local it = wp.items[i]
    if not it or gen ~= wp.gen then return end
    local thumb = THUMBS .. hs.hash.MD5(it.path .. (hs.fs.attributes(it.path, "modification") or "")) .. ".jpg"
    local function push()
      local data = readFile(thumb)
      if data then call("wallpaper", "thumb", { i = i - 1, url = "data:image/jpeg;base64," .. hs.base64.encode(data) }) end
      nextThumb()
    end
    if hs.fs.attributes(thumb) then push()
    else hs.task.new("/usr/bin/sips", push, { "-Z", "480", "-s", "format", "jpeg", it.path, "--out", thumb }):start() end
  end
  nextThumb()
end

local function wallpaperShow()
  local name = (readFile(THEME_DIR .. "/name") or ""):gsub("%s+$", "")
  local now = (readFile(THEME_DIR .. "/wallpaper") or ""):gsub("%s+$", "")
  wp.gen = (wp.gen or 0) + 1
  wp.items = {}
  for _, path in ipairs(wallpaperList(name)) do
    table.insert(wp.items, { path = path, name = path:match("([^/]+)$"), current = path == now })
  end
  call("wallpaper", "update", { theme = name, items = hs.fnutils.imap(wp.items, function(it)
    return { name = it.name, current = it.current } end) })
  loadThumbs(wp.gen)
end

local function wallpaperSet(i)
  local it = wp.items[i + 1]
  if not it then return end
  hs.task.new(os.getenv("HOME") .. "/.local/bin/theme", function(code)
    if code == 0 then call("wallpaper", "applied", i) end
  end, { "--set-wallpaper", it.path }):start()
end

-- Arrow keys etc. while the picker is open: a hotkey modal, so no window focus is needed.
local wpKeys = hs.hotkey.modal.new()
for k, action in pairs({ left = "left", right = "right", up = "up", down = "down",
                         h = "left", l = "right", k = "up", j = "down", ["return"] = "enter", space = "enter" }) do
  wpKeys:bind({}, k, function() call("wallpaper", "key", action) end, nil,
              k ~= "return" and k ~= "space" and function() call("wallpaper", "key", action) end or nil)
end
wpKeys:bind({}, "escape", function() M.hide("wallpaper") end)

-- ── Setup ────────────────────────────────────────────────────────────────────
function M.start()
  make("music", function()
    local s = scr(); return { x = s.x + s.w - 300, y = s.y + s.h - 420, w = 300, h = 420 }
  end, {
    onShow = function()
      pushMusic()
      musicTimer = hs.timer.doEvery(1, pushMusic)
    end,
    onHide = function() if musicTimer then musicTimer:stop(); musicTimer = nil end end,
    onMessage = function(m)
      if m.action == "playpause" then hs.spotify.playpause()
      elseif m.action == "next" then hs.spotify.next()
      elseif m.action == "prev" then hs.spotify.previous()
      elseif m.action == "like" then M.like() return end
      hs.timer.doAfter(0.3, pushMusic)
    end,
  })

  make("weather", function()
    local s = scr(); return { x = s.x + s.w - 470, y = s.y + BAR, w = 470, h = 340 }
  end, { onShow = fetchWeather })

  make("quote", function()
    local s = scr(); return { x = s.x, y = s.y + s.h - 300, w = 580, h = 300 }
  end, { onMessage = function(m) if m.action == "refresh" then refreshQuote() end end })

  make("todo", function()
    local s = scr(); return { x = s.x, y = s.y + BAR, w = 470, h = 520 }
  end, {
    textEntry = true,
    onShow = function() call("todo", "update", readTodos()) end,
    onMessage = function(m) if m.action == "save" then writeTodos(m.items or {}) end end,
  })

  hs.hotkey.bind(HYPER, "m", function() M.toggle("music") end)
  hs.hotkey.bind(HYPER, "w", function() M.toggle("weather") end)
  make("pomo", function()
    local s = scr(); return { x = s.x + s.w / 2 - 270, y = s.y + BAR, w = 540, h = 400 }
  end, { onShow = pomoPush, onMessage = M.pomoAction })

  make("stats", function()
    local s = scr(); return { x = s.x + s.w - 560, y = s.y + s.h / 2 - 230, w = 560, h = 460 }
  end, {
    onShow = function() collectStats(); statsTimer = hs.timer.doEvery(2, collectStats) end,
    onHide = function() if statsTimer then statsTimer:stop(); statsTimer = nil end; lastNet = nil end,
  })

  hs.hotkey.bind(HYPER, "r", function() M.toggle("todo") end)
  make("agenda", function()
    local s = scr(); return { x = s.x, y = s.y + s.h / 2 - 260, w = 520, h = 520 }
  end, {
    onShow = function() if agenda.synced > 0 then call("agenda", "update", agenda) end; fetchAgenda() end,
    onMessage = function(m)
      if m.action == "refresh" then fetchAgenda()
      elseif m.action == "open" then hs.urlevent.openURL("https://calendar.google.com/calendar/r/day/" .. (m.date or "")) end
    end,
  })
  fetchAgenda()
  M.agendaTimer = hs.timer.doEvery(600, fetchAgenda)       -- background sync every 10 min
  M.reminderTimer = hs.timer.doEvery(60, checkReminders)

  make("wallpaper", function()
    local s = scr(); return { x = s.x + s.w / 2 - 440, y = s.y + BAR, w = 880, h = math.min(620, s.h - BAR - 20) }
  end, {
    onShow = function() wallpaperShow(); wpKeys:enter() end,
    onHide = function() wpKeys:exit() end,
    onMessage = function(m) if m.action == "set" then wallpaperSet(m.i) end end,
  })

  hs.hotkey.bind(HYPER, "a", function() M.toggle("agenda") end)
  hs.hotkey.bind(HYPER, "g", function() M.toggle("wallpaper") end)
  hs.hotkey.bind(HYPER, "p", function() M.toggle("pomo") end)
  hs.hotkey.bind(HYPER, "h", function() M.toggle("stats") end)
  hs.urlevent.bind("pomo", function() M.toggle("pomo") end) -- SketchyBar click: open -g hammerspoon://pomo
  hs.hotkey.bind(HYPER, "l", function()
    M.like()
    if not widgets.music.pinned then M.show("music", 3) end -- flash the widget so you see the heart
  end)
  hs.hotkey.bind(HYPER, "q", function()
    if widgets.quote.visible then M.hide("quote") else widgets.quote.pinned = true; showQuote() end
  end)

  -- Spotify track changes → pop the music widget for a few seconds
  local lastTrack
  M.spotifyWatcher = hs.distributednotifications.new(function(_, _, info)
    info = info or {}
    local id = info["Track ID"]
    if info["Player State"] == "Playing" and id and id ~= lastTrack then
      lastTrack = id
      if widgets.music.pinned then pushMusic() else M.show("music", 7) end
    elseif widgets.music.visible then
      pushMusic()
    end
  end, "com.spotify.client.PlaybackStateChanged"):start()

  -- Quote of the day: once per day, on unlock/wake (and at startup)
  local function dailyQuote()
    if hs.settings.get("widgets.quoteShown") ~= today() then
      hs.settings.set("widgets.quoteShown", today())
      hs.timer.doAfter(1.5, function() showQuote(12) end)
    end
  end
  M.caffeinate = hs.caffeinate.watcher.new(function(e)
    if e == hs.caffeinate.watcher.screensDidUnlock or e == hs.caffeinate.watcher.systemDidWake then dailyQuote() end
  end):start()
  dailyQuote()

  -- Todo file edited elsewhere (e.g. nvim ~/.config/todo.md) → refresh the widget
  if not hs.fs.attributes(TODO_FILE) then writeTodos({}) end
  M.todoWatcher = hs.pathwatcher.new(TODO_FILE, function()
    if hs.timer.secondsSinceEpoch() - lastTodoWrite > 1 then call("todo", "update", readTodos()) end
  end):start()

  -- Follow the theme switcher live
  M.themeWatcher = hs.pathwatcher.new(THEME_DIR, function()
    hs.timer.doAfter(0.2, function() for _, w in pairs(widgets) do pushTheme(w) end end)
  end):start()
end

M.widgets = widgets
return M
