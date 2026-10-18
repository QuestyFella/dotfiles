local M = {}
local states = {}

local function notify(message, level) vim.notify(message, level or vim.log.levels.INFO, { title = "Arduino" }) end

function M.detect(path)
  -- Plugin panels may have URI names such as snacks://...; they are not files.
  if not path or path:sub(1, 1) ~= "/" then return end
  local dir = vim.fn.isdirectory(path) == 1 and path or vim.fs.dirname(path)
  while dir and dir ~= "/" do
    if vim.fn.filereadable(dir .. "/" .. vim.fs.basename(dir) .. ".ino") == 1 then return dir end
    local parent = vim.fs.dirname(dir)
    if parent == dir then return end
    dir = parent
  end
end

function M.root()
  local file = vim.api.nvim_buf_get_name(0)
  return vim.b.arduino_root or M.detect(file ~= "" and file or vim.fn.getcwd())
end

local function project()
  local root = M.root()
  if not root then notify("Open a sketch (Sketch/Sketch.ino), or use :ArduinoNew", vim.log.levels.WARN) end
  return root
end

function M.config(root)
  local cfg = { baud = 115200 }
  local path = root .. "/.nvim-arduino.json"
  if vim.fn.filereadable(path) == 1 then
    local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    if not ok or type(data) ~= "table" then error("Invalid " .. path) end
    cfg = vim.tbl_extend("force", cfg, data)
  end
  assert(
    not cfg.fqbn or (type(cfg.fqbn) == "string" and cfg.fqbn:match "^[%w_-]+:[%w_-]+:[%w_-]+"),
    "Invalid Arduino fqbn"
  )
  assert(not cfg.port or type(cfg.port) == "string", "Invalid Arduino port")
  assert(type(cfg.baud) == "number" and cfg.baud > 0 and cfg.baud % 1 == 0, "Invalid Arduino baud rate")
  return cfg
end

local function state(root)
  states[root] = states[root] or { output = "Build output will appear here.\n", status = "Ready" }
  return states[root]
end

local function set_lines(buf, lines)
  if not buf or not vim.api.nvim_buf_is_valid(buf) then return end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
  vim.bo[buf].modifiable = false
end

local function render(root)
  local s, c = state(root), M.config(root)
  set_lines(s.output_buf, vim.split(s.output:gsub("\27%[[0-?]*[ -/]*[@-~]", ""):gsub("\r", ""), "\n"))
  set_lines(s.panel_buf, {
    "  ARDUINO",
    "  " .. vim.fs.basename(root),
    "",
    "  BOARD",
    "  " .. (c.name or c.fqbn or "Choose with Space a b"),
    "",
    "  TARGET",
    "  " .. (c.fqbn or "Not selected"),
    "",
    "  PORT",
    "  " .. (c.port or "Not selected"),
    "  " .. c.baud .. " baud",
    "",
    "  STATUS",
    "  " .. s.status,
    "",
    "  Space a b   Board",
    "  Space a o   Board options",
    "  Space a p   Port",
    "  Space a c   Compile",
    "  Space a u   Build + upload",
    "  Space a s   Serial monitor",
    "  Space a S   Close serial",
    "  Space a e   Build output",
    "  Space a k   Stop task",
    "  Space a h   Guide",
    "",
    "  q closes this panel",
  })
  vim.cmd "redrawstatus"
end

local function save(root, changes)
  local cfg = vim.tbl_extend("force", M.config(root), changes)
  local lines = { "{" }
  for i, key in ipairs(vim.fn.sort(vim.tbl_keys(cfg))) do
    lines[#lines + 1] = "  "
      .. vim.json.encode(key)
      .. ": "
      .. vim.json.encode(cfg[key])
      .. (i < vim.tbl_count(cfg) and "," or "")
  end
  lines[#lines + 1] = "}"
  vim.fn.writefile(lines, root .. "/.nvim-arduino.json")
  render(root)
end

function M.cli(args) return vim.list_extend({ "arduino-cli", "--no-color" }, args) end

local function query(args, callback)
  if vim.fn.executable "arduino-cli" ~= 1 then return notify("Install arduino-cli first", vim.log.levels.ERROR) end
  vim.system(M.cli(vim.list_extend({ "--json" }, args)), { text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then return notify(result.stderr .. result.stdout, vim.log.levels.ERROR) end
      local ok, data = pcall(vim.json.decode, result.stdout)
      if not ok then return notify("Cannot decode Arduino CLI response", vim.log.levels.ERROR) end
      callback(data)
    end)
  end)
end

function M.restart_lsp(root)
  root = root or project()
  if not root or not vim.lsp.is_enabled "arduino_language_server" then return end
  local clients = vim.lsp.get_clients { name = "arduino_language_server" }
  for _, client in ipairs(clients) do
    if client.config.root_dir == root then client:stop() end
  end
  local attempts = 0
  local function restart()
    if vim.v.exiting ~= vim.NIL then return end
    attempts = attempts + 1
    for _, client in ipairs(clients) do
      if client.config.root_dir == root and not client:is_stopped() then
        if attempts > 20 then client:stop(true) end
        return vim.defer_fn(restart, 100)
      end
    end
    if not M.config(root).fqbn then return end
    for _, buf in ipairs(vim.api.nvim_list_bufs()) do
      if
        vim.api.nvim_buf_is_loaded(buf)
        and M.detect(vim.api.nvim_buf_get_name(buf)) == root
        and vim.tbl_contains({ "arduino", "c", "cpp" }, vim.bo[buf].filetype)
      then
        local cfg = vim.deepcopy(vim.lsp.config.arduino_language_server)
        cfg.root_dir = root
        vim.lsp.start(cfg, { bufnr = buf })
      end
    end
  end
  restart()
end

function M.board(root, done)
  root = root or project()
  if not root then return end
  query({ "board", "listall" }, function(data)
    local choices = data.boards or {}
    local priority = { ["arduino:avr:uno"] = 1, ["arduino:avr:nano"] = 2, ["esp32:esp32:esp32"] = 4 }
    choices[#choices + 1] =
      { name = "Arduino Nano — ATmega328P (Old Bootloader)", fqbn = "arduino:avr:nano:cpu=atmega328old" }
    priority["arduino:avr:nano:cpu=atmega328old"] = 3
    table.sort(choices, function(a, b)
      local pa, pb = priority[a.fqbn] or 100, priority[b.fqbn] or 100
      return pa < pb or (pa == pb and a.name < b.name)
    end)
    vim.ui.select(choices, {
      prompt = "Arduino board — " .. vim.fs.basename(root),
      format_item = function(b) return b.name .. "  [" .. b.fqbn .. "]" end,
    }, function(choice)
      if not choice then return end
      save(root, { fqbn = choice.fqbn, name = choice.name })
      M.restart_lsp(root)
      if done then done(M.config(root)) end
    end)
  end)
end

local function with_board(root, done)
  local cfg = M.config(root)
  if cfg.fqbn then
    done(cfg)
  else
    M.board(root, done)
  end
end

function M.options()
  local root = project()
  if not root then return end
  with_board(root, function(cfg)
    query({ "board", "details", "-b", cfg.fqbn }, function(data)
      local options = data.config_options or {}
      if #options == 0 then return notify "This board has no extra options" end
      vim.ui.select(options, {
        prompt = "Board option",
        format_item = function(o) return o.option_label end,
      }, function(option)
        if not option then return end
        vim.ui.select(option.values, {
          prompt = option.option_label,
          format_item = function(v) return (v.selected and "● " or "  ") .. v.value_label end,
        }, function(value)
          if not value then return end
          local parts = vim.split(cfg.fqbn, ":", { plain = true })
          local selections = {}
          for _, entry in ipairs(vim.split(parts[4] or "", ",", { trimempty = true })) do
            local key, val = entry:match "^([^=]+)=(.+)$"
            if key then selections[key] = val end
          end
          selections[option.option] = value.value
          local entries = {}
          for _, key in ipairs(vim.fn.sort(vim.tbl_keys(selections))) do
            entries[#entries + 1] = key .. "=" .. selections[key]
          end
          save(root, { fqbn = table.concat(parts, ":", 1, 3) .. ":" .. table.concat(entries, ","), name = data.name })
          M.restart_lsp(root)
        end)
      end)
    end)
  end)
end

function M.port(root, done)
  root = root or project()
  if not root then return end
  query({ "board", "list" }, function(data)
    local ports = {}
    for _, device in ipairs(data.detected_ports or {}) do
      local p = device.port
      if
        p
        and p.protocol == "serial"
        and not p.address:match "Bluetooth"
        and not p.address:match "wlan%-debug"
        and not p.address:match "debug%-console"
      then
        local names = vim.tbl_map(function(b) return b.name end, device.matching_boards or {})
        ports[#ports + 1] = {
          address = p.address,
          label = p.address .. "  " .. (#names > 0 and table.concat(names, ", ") or p.label or "Unknown board"),
        }
      end
    end
    if #ports == 0 then
      return notify("No serial ports detected. Connect the board with a data cable.", vim.log.levels.WARN)
    end
    vim.ui.select(
      ports,
      { prompt = "Arduino serial port", format_item = function(p) return p.label end },
      function(choice)
        if not choice then return end
        if not M.close_serial(root) then return end
        save(root, { port = choice.address })
        if done then done(M.config(root)) end
      end
    )
  end)
end

local function with_port(root, done)
  local cfg = M.config(root)
  if cfg.port and vim.uv.fs_stat(cfg.port) then
    done(cfg)
  else
    M.port(root, done)
  end
end

local function pane(root, key, split, title)
  local s = state(root)
  if not s[key] or not vim.api.nvim_buf_is_valid(s[key]) then
    s[key] = vim.api.nvim_create_buf(false, true)
    vim.bo[s[key]].bufhidden = "hide"
    vim.bo[s[key]].filetype = "arduino_panel"
    vim.b[s[key]].arduino_root = root
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = s[key], silent = true })
  end
  local wins = vim.fn.win_findbuf(s[key])
  if #wins > 0 then
    vim.api.nvim_set_current_win(wins[1])
  else
    vim.cmd(split)
    vim.api.nvim_win_set_buf(0, s[key])
  end
  vim.wo.number, vim.wo.relativenumber, vim.wo.signcolumn = false, false, "no"
  vim.wo.wrap = true
  vim.wo.winbar = " " .. title:gsub("%%", "%%%%")
  render(root)
end

function M.output(root)
  root = root or project()
  if root then pane(root, "output_buf", "botright 12split", "Arduino build output") end
end

function M.workspace()
  local root = project()
  if not root then return end
  local win = vim.api.nvim_get_current_win()
  M.output(root)
  vim.api.nvim_set_current_win(win)
  pane(root, "panel_buf", "botright 38vsplit", "Arduino sketch")
  vim.api.nvim_set_current_win(win)
end

function M.run(root, label, args, done)
  local s = state(root)
  if s.job then return notify("A task is already running for this sketch", vim.log.levels.WARN) end
  local task = { cancelled = false }
  s.job, s.status, s.output = task, label .. "…", "$ " .. table.concat(M.cli(args), " ") .. "\n\n"
  render(root)
  notify(label .. ": " .. vim.fs.basename(root))
  local output = {}
  local function stream(_, data)
    if not data then return end
    output[#output + 1] = data
    vim.schedule(function()
      s.output = s.output .. data
      render(root)
    end)
  end
  local ok, job = pcall(
    vim.system,
    M.cli(args),
    { cwd = root, text = true, stdout = stream, stderr = stream },
    function(result)
      vim.schedule(function()
        s.job = nil
        s.status = task.cancelled and "Cancelled" or label .. (result.code == 0 and " OK" or " failed")
        render(root)
        local text = table.concat(output):gsub("\27%[[0-?]*[ -/]*[@-~]", ""):gsub("\r", "")
        local lines = vim.split(text, "\n")
        table.insert(lines, 1, "ARDUINO_DIRECTORY " .. root)
        vim.fn.setqflist({}, " ", {
          title = "Arduino " .. label .. " — " .. vim.fs.basename(root),
          lines = lines,
          efm = "%DARDUINO_DIRECTORY %f,%f:%l:%c: %t%*[^:]: %m,%f:%l: %t%*[^:]: %m,%-G%.%#",
        })
        notify(s.status, result.code == 0 and vim.log.levels.INFO or vim.log.levels.WARN)
        if result.code ~= 0 and not task.cancelled and M.root() == root then
          if #vim.fn.getqflist() > 0 then
            vim.cmd "copen"
            vim.b.arduino_root = root
          else
            M.output(root)
          end
        end
        if not task.cancelled and result.code == 0 and done then done() end
      end)
    end
  )
  if ok then
    task.handle = job
  else
    s.job, s.status = nil, "Could not start task"
    s.output = s.output .. tostring(job)
    render(root)
    notify(tostring(job), vim.log.levels.ERROR)
  end
end

function M.build_path(root, fqbn)
  return vim.fn.stdpath "cache" .. "/arduino/" .. vim.fn.sha256(root .. "\n" .. fqbn):sub(1, 24)
end

local function save_sketch(root)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_loaded(buf)
      and vim.bo[buf].buftype == ""
      and vim.bo[buf].modified
      and M.detect(vim.api.nvim_buf_get_name(buf)) == root
    then
      vim.api.nvim_buf_call(buf, function() vim.cmd "write" end)
    end
  end
end

function M.build(upload)
  local root = project()
  if not root then return end
  with_board(root, function()
    local function compile(cfg)
      if state(root).job then return notify("A task is already running for this sketch", vim.log.levels.WARN) end
      save_sketch(root)
      local args = { "compile", "--fqbn", cfg.fqbn, "--warnings", "all", "--build-path", M.build_path(root, cfg.fqbn) }
      if upload then
        if not M.close_serial(root, cfg.port) then return end
        vim.list_extend(args, { "--upload", "--verify", "--port", cfg.port })
      end
      args[#args + 1] = root
      M.run(root, upload and "Build + upload" or "Compile", args)
    end
    if upload then
      with_port(root, compile)
    else
      compile(M.config(root))
    end
  end)
end

function M.close_serial(root, port)
  root = root or project()
  if not root then return false end
  for other, s in pairs(states) do
    local serial = s.serial
    if serial and (other == root or (port and serial.port == port)) then
      if vim.fn.jobwait({ serial.job }, 0)[1] == -1 then
        vim.fn.jobstop(serial.job)
        if vim.fn.jobwait({ serial.job }, 1500)[1] == -1 then
          notify("Serial monitor is still stopping; try again", vim.log.levels.WARN)
          return false
        end
      end
      s.serial = nil
    end
  end
  return true
end

function M.serial()
  local root = project()
  if not root then return end
  if state(root).job then return notify("Wait for the current task before opening serial", vim.log.levels.WARN) end
  with_board(root, function()
    with_port(root, function(cfg)
      local s = state(root)
      if
        s.serial
        and vim.api.nvim_buf_is_valid(s.serial.buf)
        and vim.fn.jobwait({ s.serial.job }, 0)[1] == -1
        and s.serial.port == cfg.port
        and s.serial.baud == cfg.baud
      then
        local wins = vim.fn.win_findbuf(s.serial.buf)
        if #wins > 0 then
          vim.api.nvim_set_current_win(wins[1])
        else
          vim.cmd "botright 12split"
          vim.api.nvim_win_set_buf(0, s.serial.buf)
        end
        vim.cmd "startinsert"
        return
      end
      if not M.close_serial(root, cfg.port) then return end
      local previous = s.serial_buf
      local wins = previous and vim.api.nvim_buf_is_valid(previous) and vim.fn.win_findbuf(previous) or {}
      if #wins > 0 then
        vim.api.nvim_set_current_win(wins[1])
      else
        vim.cmd "botright 12split"
      end
      local buf = vim.api.nvim_create_buf(false, true)
      vim.api.nvim_win_set_buf(0, buf)
      if previous and vim.api.nvim_buf_is_valid(previous) then vim.api.nvim_buf_delete(previous, { force = true }) end
      local job = vim.fn.jobstart(
        M.cli { "monitor", "--port", cfg.port, "--fqbn", cfg.fqbn, "--config", "baudrate=" .. cfg.baud, "--timestamp" },
        { term = true, cwd = root }
      )
      if job <= 0 then return notify("Could not start serial monitor", vim.log.levels.ERROR) end
      s.serial = { job = job, buf = buf, port = cfg.port, baud = cfg.baud }
      s.serial_buf = buf
      vim.b.arduino_root = root
      vim.bo.bufhidden = "hide"
      vim.wo.number, vim.wo.relativenumber = false, false
      vim.wo.winbar = " Arduino serial | " .. cfg.port .. " | " .. cfg.baud .. " baud | Esc Esc: normal mode"
      vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { buffer = buf })
      for _, dir in ipairs { "h", "j", "k", "l" } do
        vim.keymap.set("t", "<C-" .. dir .. ">", "<C-\\><C-n><C-w>" .. dir, { buffer = buf })
      end
      vim.cmd "startinsert"
    end)
  end)
end

function M.baud()
  local root = project()
  if not root then return end
  vim.ui.input({ prompt = "Serial baud rate: ", default = tostring(M.config(root).baud) }, function(value)
    if not value then return end
    local baud = tonumber(value)
    if not baud or baud <= 0 or baud % 1 ~= 0 then return notify("Enter a positive integer", vim.log.levels.WARN) end
    if not M.close_serial(root) then return end
    save(root, { baud = baud })
  end)
end

function M.library()
  local root = project()
  if not root then return end
  vim.ui.input({ prompt = "Search Arduino libraries: " }, function(term)
    if not term or term == "" then return end
    query({ "lib", "search", term }, function(data)
      local libraries = data.libraries or {}
      if #libraries == 0 then return notify "No libraries found; try :ArduinoUpdateIndex" end
      vim.ui.select(libraries, {
        prompt = "Install library",
        format_item = function(lib) return lib.name .. " — " .. (lib.latest.author or "") end,
      }, function(lib)
        if lib then
          M.run(root, "Install " .. lib.name, { "lib", "install", lib.name }, function() M.restart_lsp(root) end)
        end
      end)
    end)
  end)
end

function M.new()
  vim.ui.input({ prompt = "New sketch folder: ", default = vim.fn.getcwd() .. "/", completion = "dir" }, function(path)
    if not path or path == "" then return end
    path = vim.fs.normalize(vim.fn.fnamemodify(vim.fn.expand(path), ":p")):gsub("/$", "")
    local name = vim.fs.basename(path)
    if not name:match "^[%a_][%w_-]*$" or #name > 63 then
      return notify(
        "Use a sketch name of 1–63 letters, digits, _ or -, starting with a letter or _",
        vim.log.levels.WARN
      )
    end
    if vim.uv.fs_stat(path) then return notify("That folder already exists; choose a new name", vim.log.levels.WARN) end
    vim.fn.mkdir(path, "p")
    local file = path .. "/" .. name .. ".ino"
    vim.fn.writefile({
      "void setup() {",
      "  Serial.begin(115200);",
      "}",
      "",
      "void loop() {",
      '  Serial.println("Hello from Arduino");',
      "  delay(1000);",
      "}",
    }, file)
    vim.cmd.edit(vim.fn.fnameescape(file))
    M.board(path)
  end)
end

function M.status()
  local root = M.root()
  if not root then return "" end
  local ok, c = pcall(M.config, root)
  if not ok then return "Arduino | invalid settings" end
  return "Arduino | "
    .. (c.name or c.fqbn or "select board")
    .. (c.port and " | " .. vim.fs.basename(c.port) or "")
    .. (state(root).job and " | " .. state(root).status or "")
end

function M.setup()
  vim.filetype.add { extension = { ino = "arduino" } }
  vim.treesitter.language.register("cpp", "arduino")
  local group = vim.api.nvim_create_augroup("arduino_mode", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = "arduino",
    callback = function()
      vim.b.autoformat = false
      vim.opt_local.expandtab, vim.opt_local.shiftwidth, vim.opt_local.tabstop = true, 2, 2
      vim.opt_local.commentstring = "// %s"
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = ".nvim-arduino.json",
    callback = function(ev)
      local root = vim.fs.dirname(ev.file)
      render(root)
      M.restart_lsp(root)
    end,
  })
  local actions = {
    Board = function() M.board() end,
    Options = M.options,
    Port = function() M.port() end,
    Build = function() M.build(false) end,
    Upload = function() M.build(true) end,
    Serial = M.serial,
    SerialClose = function() M.close_serial() end,
    Baud = M.baud,
    New = M.new,
    Library = M.library,
    Workbench = M.workspace,
    Output = function() M.output() end,
    Restart = function() M.restart_lsp() end,
    Stop = function()
      local root = project()
      local job = root and state(root).job
      if job then
        job.cancelled = true
        job.handle:kill(15)
      end
    end,
    UpdateIndex = function()
      local root = project()
      if root then
        M.run(
          root,
          "Update board index",
          { "core", "update-index" },
          function() M.run(root, "Update library index", { "lib", "update-index" }) end
        )
      end
    end,
    Settings = function()
      local root = project()
      if root then
        save(root, {})
        vim.cmd.edit(vim.fn.fnameescape(root .. "/.nvim-arduino.json"))
      end
    end,
    Health = function() vim.cmd "checkhealth arduino" end,
    Help = function() vim.cmd.edit(vim.fn.stdpath "config" .. "/ARDUINO.md") end,
  }
  for name, action in pairs(actions) do
    vim.api.nvim_create_user_command("Arduino" .. name, action, {})
  end
  vim.api.nvim_create_user_command("Arduino", function()
    vim.ui.select(vim.fn.sort(vim.tbl_keys(actions)), { prompt = "Arduino actions" }, function(name)
      if name then actions[name]() end
    end)
  end, {})
end

return M
