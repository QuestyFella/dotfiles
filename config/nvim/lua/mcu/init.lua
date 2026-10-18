local M = {}
local jobs, presets, terminals = {}, {}, {}
local function notify(message, level) vim.notify(message, level or vim.log.levels.INFO, { title = "MCU" }) end
function M.root()
  if vim.b.mcu_root then return vim.b.mcu_root end
  if vim.t.mcu_root then return vim.t.mcu_root end
  local file = vim.api.nvim_buf_get_name(0)
  return vim.fs.root(
    file ~= "" and file or vim.fn.getcwd(),
    { ".nvim-mcu.json", "CMakePresets.json", "CMakeLists.txt", "Makefile", ".git" }
  ) or vim.fn.getcwd()
end
function M.config(root)
  root = root or M.root()
  local cfg = { preset = "Debug", build_system = "cmake", gdb_target = "localhost:3333", baud = 115200 }
  local path = root .. "/.nvim-mcu.json"
  if vim.fn.filereadable(path) == 1 then
    local ok, data = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    if not ok or type(data) ~= "table" then error("Invalid " .. path) end
    cfg = vim.tbl_extend("force", cfg, data)
  end
  cfg.preset = presets[root] or cfg.preset
  cfg.build_dir = cfg.build_dir or ("build/" .. cfg.preset)
  cfg.build_dir = cfg.build_dir:sub(1, 1) == "/" and cfg.build_dir or root .. "/" .. cfg.build_dir
  return cfg, root
end
function M.run(argv, root, done, cwd)
  if jobs[root] then return notify("A task is already running in this project", vim.log.levels.WARN) end
  vim.cmd "wall"
  local efm = vim.o.errorformat
  notify(table.concat(argv, " "))
  jobs[root] = vim.system(argv, { cwd = cwd or root, text = true }, function(result)
    vim.schedule(function()
      jobs[root] = nil
      local output = (result.stdout or "") .. "\n" .. (result.stderr or "")
      output = output:gsub("\27%[[0-?]*[ -/]*[@-~]", ""):gsub("\r", "")
      local lines = vim.split(output, "\n")
      table.insert(lines, 1, "MCU_DIRECTORY " .. root)
      vim.fn.setqflist({}, " ", { title = table.concat(argv, " "), lines = lines, efm = "%DMCU_DIRECTORY %f," .. efm })
      local items = vim.fn.getqflist()
      items = vim.tbl_filter(function(item) return not item.text:match "^MCU_DIRECTORY " end, items)
      vim.fn.setqflist(items, "r")
      notify("Task exited " .. result.code, result.code == 0 and vim.log.levels.INFO or vim.log.levels.ERROR)
      if result.code ~= 0 then vim.cmd "copen" end
      if result.code == 0 and done then done() end
    end)
  end)
end
function M.terminal(argv, root, name)
  local key = root .. "/" .. (name or argv[1])
  local existing = terminals[key]
  if existing and vim.api.nvim_buf_is_valid(existing.buf) and vim.fn.jobwait({ existing.job }, 0)[1] == -1 then
    if not vim.deep_equal(existing.argv, argv) then
      return notify(
        "Stop the existing " .. (name or argv[1]) .. " session before changing its port/settings",
        vim.log.levels.WARN
      )
    end
    local windows = vim.fn.win_findbuf(existing.buf)
    if #windows > 0 then
      vim.api.nvim_set_current_win(windows[1])
    else
      vim.cmd "botright 12split"
      vim.api.nvim_win_set_buf(0, existing.buf)
    end
    vim.cmd "startinsert"
    return
  end
  vim.cmd "botright 15split"
  vim.cmd "enew"
  local id = vim.fn.jobstart(argv, { term = true, cwd = root })
  if id <= 0 then return notify("Could not start " .. argv[1], vim.log.levels.ERROR) end
  terminals[key] = { buf = vim.api.nvim_get_current_buf(), job = id, argv = vim.deepcopy(argv) }
  vim.b.mcu_root = root
  vim.bo.bufhidden = "hide"
  vim.wo.winbar = " " .. (name or argv[1]) .. "  |  Esc Esc: normal mode  |  Ctrl-h/j/k/l: panes"
  vim.keymap.set("t", "<Esc><Esc>", "<C-\\><C-n>", { buffer = true, desc = "Terminal normal mode" })
  for _, direction in ipairs { "h", "j", "k", "l" } do
    vim.keymap.set(
      "t",
      "<C-" .. direction .. ">",
      "<C-\\><C-n><C-w>" .. direction,
      { buffer = true, desc = "Focus adjacent pane" }
    )
  end
  vim.cmd "startinsert"
end
function M.configure()
  local c, root = M.config()
  if c.build_system ~= "cmake" then
    return notify "Make projects: use MCUBuild; generate compile_commands.json with Bear"
  end
  local argv = { "cmake" }
  if vim.fn.filereadable(root .. "/CMakePresets.json") == 1 then vim.list_extend(argv, { "--preset", c.preset }) end
  vim.list_extend(argv, { "-S", root, "-B", c.build_dir, "-DCMAKE_EXPORT_COMPILE_COMMANDS=ON" })
  M.run(argv, root, function() vim.cmd "lsp restart clangd" end)
end
function M.build()
  local c, root = M.config()
  local argv = c.build_system == "make" and { "make", "-j" .. math.max(1, vim.uv.available_parallelism()) }
    or { "cmake", "--build", c.build_dir, "--parallel" }
  if c.build_target then
    if c.build_system ~= "make" then table.insert(argv, "--target") end
    table.insert(argv, c.build_target)
  end
  M.run(argv, root)
end
function M.preset()
  local _, root = M.config()
  vim.system({ "cmake", "--list-presets" }, { cwd = root, text = true }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then return notify(result.stderr, vim.log.levels.ERROR) end
      local choices = {}
      for name in result.stdout:gmatch '"([^"]+)"' do
        choices[#choices + 1] = name
      end
      vim.ui.select(choices, { prompt = "Configure preset" }, function(choice)
        if choice then
          presets[root] = choice
          notify("Selected " .. choice .. "; run MCUConfigure")
        end
      end)
    end)
  end)
end
function M.elf(callback)
  local c, root = M.config()
  if c.elf then
    local path = c.elf:sub(1, 1) == "/" and c.elf or root .. "/" .. c.elf
    if vim.fn.filereadable(path) ~= 1 then return notify("ELF missing: " .. path, vim.log.levels.ERROR) end
    return callback(path, c, root)
  end
  local files = vim.fn.glob(c.build_dir .. "/**/*.elf", false, true)
  if #files == 0 then return notify("Build first, or set elf in .nvim-mcu.json", vim.log.levels.WARN) end
  if #files == 1 then return callback(files[1], c, root) end
  vim.ui.select(files, { prompt = "Firmware ELF" }, function(path)
    if path then callback(path, c, root) end
  end)
end
function M.flash()
  M.elf(function(path, _, root)
    vim.ui.select(
      { "Cancel", "Flash and reset" },
      { prompt = "Write " .. vim.fs.basename(path) .. " to ST-LINK target?" },
      function(choice)
        if choice == "Flash and reset" then
          local executable = vim.uv.fs_realpath(vim.fn.exepath "STM32_Programmer_CLI")
          if not executable then return notify("STM32CubeProgrammer CLI not found", vim.log.levels.ERROR) end
          -- CubeProgrammer locates its device database relative to its installation.
          M.run({ executable, "-c", "port=SWD", "-w", path, "-v", "-rst" }, root, nil, vim.fs.dirname(executable))
        end
      end
    )
  end)
end
function M.server()
  local c, root = M.config()
  if not c.openocd_target then
    return notify("Set openocd_target (e.g. target/stm32f4x.cfg) in .nvim-mcu.json", vim.log.levels.WARN)
  end
  M.terminal(
    { "openocd", "-f", c.openocd_interface or "interface/stlink.cfg", "-f", c.openocd_target },
    root,
    "OpenOCD"
  )
end
function M.debug()
  if require("dap").session() then return require("mcu.debug").open() end
  M.elf(
    function(path, c, root)
      require("dap").run {
        name = "MCU: attach to GDB server",
        type = "mcu_gdb",
        request = "attach",
        program = path,
        target = c.gdb_target,
        mcu_root = root,
      }
    end
  )
end
function M.serial()
  local c, root = M.config()
  vim.ui.select(
    vim.fn.glob("/dev/cu.*", false, true),
    { prompt = "Serial port (picocom: Ctrl-A Ctrl-X exits)" },
    function(port)
      if port then M.terminal({ "picocom", "--baud", tostring(c.baud), port }, root, "Serial") end
    end
  )
end
function M.init()
  local root = M.root()
  local path = root .. "/.nvim-mcu.json"
  if vim.fn.filereadable(path) == 0 then
    vim.fn.writefile({
      "{",
      '  "preset": "Debug",',
      '  "build_system": "cmake",',
      '  "gdb_target": "localhost:3333",',
      '  "baud": 115200',
      "}",
    }, path)
  end
  vim.cmd.edit(vim.fn.fnameescape(path))
end
function M.setup()
  vim.filetype.add { extension = { ioc = "dosini", ld = "ld", s = "asm", S = "asm" } }
  vim.api.nvim_create_autocmd("FileType", {
    group = vim.api.nvim_create_augroup("mcu_editing", { clear = true }),
    pattern = { "c", "cpp" },
    callback = function()
      vim.b.autoformat = false
      vim.opt_local.expandtab = true
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
    end,
  })
  local actions = {
    Init = M.init,
    Configure = M.configure,
    Build = M.build,
    Preset = M.preset,
    Flash = M.flash,
    Server = M.server,
    Debug = M.debug,
    Serial = M.serial,
    Size = function()
      M.elf(function(path, _, root) M.run({ "arm-none-eabi-size", "-A", path }, root) end)
    end,
    Stop = function()
      local task = jobs[M.root()]
      if task then task:kill(15) end
    end,
    Help = function() vim.cmd.edit(vim.fn.stdpath "config" .. "/MCU.md") end,
    Health = function() vim.cmd "checkhealth mcu" end,
  }
  for name, action in pairs(actions) do
    vim.api.nvim_create_user_command("MCU" .. name, action, {})
  end
  local debug_commands = {
    Workbench = "toggle",
    Views = "views",
    Registers = "registers",
    Peripherals = "peripherals",
    Disassembly = "disassembly",
    Trace = "trace",
    Refresh = "refresh",
    Watch = "watch",
    Watchpoint = "watchpoint",
    Logpoint = "logpoint",
    Disconnect = "disconnect",
    TraceExport = "export_trace",
  }
  for name, action in pairs(debug_commands) do
    vim.api.nvim_create_user_command("MCU" .. name, function()
      require "dapui"
      local debug = require "mcu.debug"
      if debug[action] then
        debug[action]()
      else
        debug.float(action)
      end
    end, {})
  end
  for name, action in pairs { Memory = "memory", Peripheral = "add_peripheral" } do
    vim.api.nvim_create_user_command("MCU" .. name, function(opts)
      require "dapui"
      require("mcu.debug")[action](opts.args)
    end, { nargs = "*" })
  end
end
return M
