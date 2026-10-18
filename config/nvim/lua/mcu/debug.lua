local M = {}
local api = vim.api
local ns = api.nvim_create_namespace "mcu_debug"
local state = { status = "idle", epoch = 0, stop = 0, registers = {}, peripherals = {}, history = {} }
local panes, workspace, origin, source_window = {}, nil, nil, nil
local titles = {
  registers = "CPU REGISTERS",
  peripherals = "PERIPHERAL WATCHES",
  memory = "MEMORY",
  disassembly = "DISASSEMBLY",
  trace = "REGISTER HISTORY",
}

local function notify(message) vim.notify(message, vim.log.levels.INFO, { title = "STM32 debug" }) end
local function is_mcu(session) return session and session.config.type == "mcu_gdb" end
local function current() return require("dap").session() end
local function stopped() return is_mcu(current()) and state.status == "stopped" end
local function clean(value) return tostring(value or ""):gsub("[\r\n]+", " ") end

local function highlights()
  api.nvim_set_hl(0, "MCUChanged", { default = true, link = "DiagnosticWarn" })
  api.nvim_set_hl(0, "MCUHeading", { default = true, link = "Title" })
  api.nvim_set_hl(0, "MCUMuted", { default = true, link = "Comment" })
end

local function header(name)
  local status = state.status == "running" and "RUNNING | last halted sample" or state.status:upper()
  return titles[name] .. "  |  " .. status
end

local function buffer(name)
  local pane = panes[name]
  if pane.buf and api.nvim_buf_is_valid(pane.buf) then return pane.buf end
  pane.buf = api.nvim_create_buf(false, true)
  api.nvim_buf_set_name(pane.buf, "mcu-debug://" .. name)
  vim.bo[pane.buf].filetype = "mcu_debug"
  vim.bo[pane.buf].bufhidden = "hide"
  vim.bo[pane.buf].swapfile = false
  vim.bo[pane.buf].modifiable = false
  local function map(key, fn, desc) vim.keymap.set("n", key, fn, { buffer = pane.buf, desc = desc }) end
  map("r", M.refresh, "Refresh halted target")
  map("?", M.views, "All debug views")
  if name == "peripherals" then
    map("a", M.add_peripheral, "Add peripheral expression")
    map("dd", M.remove_peripheral, "Remove peripheral watch")
  elseif name == "memory" then
    map("a", M.memory, "Change memory address")
  elseif name == "trace" then
    map("C", function()
      state.history = {}
      M.render()
    end, "Clear register history")
    map("s", M.export_trace, "Save history to file")
  end
  return pane.buf
end

local function draw(name)
  local pane = panes[name]
  if not pane.buf or not api.nvim_buf_is_valid(pane.buf) then return end
  vim.b[pane.buf].mcu_root = state.root
  local lines = { header(name), pane.hint or "r refresh  |  ? views", "" }
  vim.list_extend(lines, pane.lines or { "Attach with Space m d, then pause or step." })
  vim.bo[pane.buf].modifiable = true
  api.nvim_buf_set_lines(pane.buf, 0, -1, false, lines)
  vim.bo[pane.buf].modifiable = false
  api.nvim_buf_clear_namespace(pane.buf, ns, 0, -1)
  for row, group in pairs(vim.tbl_extend("force", { [1] = "MCUHeading", [2] = "MCUMuted" }, pane.marks or {})) do
    if row <= #lines then api.nvim_buf_set_extmark(pane.buf, ns, row - 1, 0, { line_hl_group = group }) end
  end
end

function M.render()
  if panes.trace then
    panes.trace.lines = #state.history > 0 and state.history
      or { "Changes are sampled at debugger stops.", "No SWO / continuous execution trace." }
  end
  for name in pairs(panes) do
    draw(name)
  end
  vim.cmd "redrawstatus"
end

local function put(name, lines, marks)
  panes[name].lines, panes[name].marks = lines, marks or {}
  draw(name)
end

local function record(lines)
  for i = #lines, 1, -1 do
    table.insert(state.history, 1, lines[i])
  end
  while #state.history > 400 do
    table.remove(state.history)
  end
  M.render()
end

local function visible(name)
  local buf = panes[name].buf
  return buf and #vim.fn.win_findbuf(buf) > 0
end

local function request(command, args, callback, epoch)
  local session = current()
  epoch = epoch or state.epoch
  if not stopped() then return end
  session:request(command, args, function(err, response)
    -- A response from a previous stop/session must never replace newer data.
    if session ~= current() or epoch ~= state.epoch or not stopped() then return end
    callback(err, response or {})
  end)
end

local function evaluate(expression, context, callback, epoch)
  request(
    "evaluate",
    { expression = expression, context = context, frameId = state.frame, format = { hex = true } },
    callback,
    epoch
  )
end

local function error_text(err) return clean(type(err) == "table" and (err.message or vim.inspect(err)) or err) end

local function storage_path()
  return vim.fn.stdpath "data" .. "/mcu/peripherals-" .. vim.fn.sha256(state.root):sub(1, 16) .. ".json"
end

local function save_peripherals()
  if not state.root then return end
  local path = storage_path()
  vim.fn.mkdir(vim.fs.dirname(path), "p")
  vim.fn.writefile({ vim.json.encode(state.peripherals) }, path)
end

local function load_project(root)
  if state.root == root then return end
  state.registers, state.history, state.memory, state.frame = {}, {}, nil, nil
  if not current() then state.status = "idle" end
  for name in pairs(panes) do
    put(name, { "Attach with Space m d, then pause or step." })
  end
  state.root, state.peripherals, state.peripheral_values = root, {}, {}
  local cfg = require("mcu").config(root)
  local path = storage_path()
  local entries = cfg.peripheral_watches or {}
  if vim.fn.filereadable(path) == 1 then
    local ok, saved = pcall(vim.json.decode, table.concat(vim.fn.readfile(path), "\n"))
    if ok and type(saved) == "table" then entries = saved end
  end
  for _, item in ipairs(entries) do
    if type(item) == "string" then item = { name = item, expression = item } end
    if type(item) == "table" and type(item.expression) == "string" and #state.peripherals < 32 then
      table.insert(state.peripherals, { name = item.name or item.expression, expression = item.expression })
    end
  end
end

local function peripheral_placeholder()
  local lines = {}
  for _, item in ipairs(state.peripherals) do
    local value = (state.peripheral_values or {})[item.expression] or "<pause to read>"
    lines[#lines + 1] = item.name .. " = " .. value
  end
  if #lines == 0 then
    lines =
      { "No peripheral watches.", "a: add a CMSIS expression or typed address.", "Example: *(unsigned int *)0x..." }
  end
  put("peripherals", lines)
end

local function sample_registers(epoch, trace)
  evaluate("info registers", "repl", function(err, body)
    if err then return put("registers", { error_text(err) }) end
    local lines, marks, values, changes = {}, {}, {}, {}
    for line in (body.result or ""):gmatch "[^\r\n]+" do
      local name, value, detail = line:match "^(%S+)%s+(%S+)%s*(.*)$"
      if name then
        local before = state.registers[name]
        local changed = before ~= nil and before ~= value
        values[name] = value
        lines[#lines + 1] = string.format("%s %-8s %s", changed and "*" or " ", name, value)
        if value == "<unavailable>" and detail ~= "" then lines[#lines] = lines[#lines] .. " " .. detail end
        if changed then
          marks[#lines + 3] = "MCUChanged"
          changes[#changes + 1] = string.format("  %s: %s -> %s", name, before, value)
        end
      end
    end
    state.registers = values
    put("registers", #lines > 0 and lines or { "No registers returned by GDB." }, marks)
    if trace then
      local entry = {
        string.format(
          "#%03d  %s  %s  %s",
          state.stop,
          os.date "%H:%M:%S",
          state.reason or "halt",
          state.location or ""
        ),
      }
      vim.list_extend(
        entry,
        #changes > 0 and changes
          or { state.stop == 1 and "  Initial register snapshot." or "  No CPU register changes." }
      )
      record(entry)
    end
  end, epoch)
end

local function sample_peripherals(epoch, trace)
  if #state.peripherals == 0 then return peripheral_placeholder() end
  local lines, marks, values, changes = {}, {}, {}, {}
  local entries = vim.deepcopy(state.peripherals)
  local function next_item(index)
    local item = entries[index]
    if not item then
      state.peripheral_values = values
      put("peripherals", lines, marks)
      if trace and #changes > 0 then
        table.insert(changes, 1, string.format("#%03d  peripheral changes", state.stop))
        record(changes)
      end
      return
    end
    -- Hover context prevents assignments and inferior function calls in GDB.
    evaluate(item.expression, "hover", function(err, body)
      local value = err and ("<" .. error_text(err) .. ">") or clean(body.result)
      local before = (state.peripheral_values or {})[item.expression]
      local changed = not err and before ~= nil and before ~= value
      values[item.expression] = not err and value or nil
      lines[#lines + 1] = (changed and "* " or "  ") .. item.name .. " = " .. value
      if changed then
        marks[#lines + 3] = "MCUChanged"
        changes[#changes + 1] = "  " .. item.name .. ": " .. before .. " -> " .. value
      elseif err then
        marks[#lines + 3] = "DiagnosticError"
      end
      next_item(index + 1)
    end, epoch)
  end
  next_item(1)
end

local function address(expression, callback, epoch)
  evaluate("(unsigned long)(" .. expression .. ")", "hover", function(err, body)
    if err then return callback(err) end
    local value = (body.result or ""):match "0x[%da-fA-F]+" or (body.result or ""):match "^%d+$"
    if not value then return callback "GDB did not return an address" end
    callback(nil, value)
  end, epoch)
end

local function sample_memory(epoch)
  if not state.memory or not visible "memory" then return end
  address(state.memory, function(err, value)
    if err then return put("memory", { error_text(err) }) end
    evaluate(
      "x/32bx " .. value,
      "repl",
      function(read_err, body)
        put("memory", read_err and { error_text(read_err) } or vim.split(vim.trim(body.result or ""), "\n"))
      end,
      epoch
    )
  end, epoch)
end

local function sample_disassembly(epoch)
  if not visible "disassembly" then return end
  address("$pc", function(err, value)
    if err then return put("disassembly", { error_text(err) }) end
    request(
      "disassemble",
      { memoryReference = value, instructionCount = 24, resolveSymbols = true },
      function(dis_err, body)
        if dis_err then return put("disassembly", { error_text(dis_err) }) end
        local lines = {}
        for i, instruction in ipairs(body.instructions or {}) do
          lines[#lines + 1] = string.format(
            "%s %s  %-10s %s",
            i == 1 and ">" or " ",
            instruction.address,
            instruction.instructionBytes or "",
            instruction.instruction
          )
        end
        put("disassembly", lines, { [4] = "MCUChanged" })
      end,
      epoch
    )
  end, epoch)
end

function M.refresh(trace)
  if not stopped() then
    if trace ~= true then notify "Pause the MCU before refreshing registers or memory." end
    return
  end
  state.epoch = state.epoch + 1
  local epoch = state.epoch
  local session = current()
  local thread = state.thread or session.stopped_thread_id
  if not thread then return end
  request("stackTrace", { threadId = thread, startFrame = 0, levels = 1 }, function(err, body)
    local frame = (body.stackFrames or {})[1]
    if err or not frame then return put("registers", { error_text(err or "No halted stack frame") }) end
    state.frame = frame.id
    state.location = (frame.name or "?") .. (frame.line and (":" .. frame.line) or "")
    sample_registers(epoch, trace == true)
    sample_peripherals(epoch, trace == true)
    sample_memory(epoch)
    sample_disassembly(epoch)
  end, epoch)
end

function M.status()
  if state.status == "idle" and not workspace then return "" end
  return "MCU " .. state.status:upper()
end

function M.toolbar()
  if api.nvim_win_get_width(0) < 100 then
    return "%#MCUHeading# " .. M.status() .. " %*  F5 run  F6 pause  |  Space m v: views"
  end
  return "%#MCUHeading# " .. M.status() .. " %*  F5 run  F6 pause  F9 break  F10 over  F11 into  F12 out"
end

function M.open()
  local dapui = require "dapui"
  local root = is_mcu(current()) and current().config.mcu_root or require("mcu").root()
  local changed_project = state.root ~= root
  local source = api.nvim_get_current_buf()
  load_project(root)
  if workspace and api.nvim_tabpage_is_valid(workspace) then
    api.nvim_set_current_tabpage(workspace)
    vim.t.mcu_root = state.root
    if changed_project and source_window and api.nvim_win_is_valid(source_window) and vim.bo[source].buftype == "" then
      api.nvim_win_set_buf(source_window, source)
    end
    M.render()
    return
  end
  peripheral_placeholder()
  origin = api.nvim_get_current_tabpage()
  if vim.bo[source].buftype ~= "" then
    for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
      local candidate = api.nvim_win_get_buf(win)
      if vim.bo[candidate].buftype == "" then
        source = candidate
        break
      end
    end
  end
  vim.cmd "tab split"
  if vim.bo[source].buftype == "" then
    api.nvim_win_set_buf(0, source)
  else
    vim.cmd "enew"
  end
  workspace, source_window = api.nvim_get_current_tabpage(), api.nvim_get_current_win()
  vim.t.mcu_root = root
  vim.t.mcu_workspace = true
  vim.wo[source_window].winbar = "%{%v:lua.require'mcu.debug'.toolbar()%}"
  -- Keep source readable on laptop terminals; all panes remain available as floats.
  if vim.o.columns >= 160 and vim.o.lines >= 40 then
    dapui.open { reset = true }
  elseif vim.o.columns >= 110 and vim.o.lines >= 32 then
    dapui.open { layout = 2, reset = true }
    dapui.open { layout = 3, reset = true }
  else
    dapui.open { layout = 3, reset = true }
  end
  if api.nvim_win_is_valid(source_window) then api.nvim_set_current_win(source_window) end
  M.render()
end

function M.close()
  if not workspace or not api.nvim_tabpage_is_valid(workspace) then
    workspace = nil
    return
  end
  api.nvim_set_current_tabpage(workspace)
  require("dapui").close()
  if source_window and api.nvim_win_is_valid(source_window) then vim.wo[source_window].winbar = "" end
  vim.t.mcu_root, vim.t.mcu_workspace = nil, nil
  if #api.nvim_list_tabpages() > 1 then vim.cmd "tabclose" end
  workspace, source_window = nil, nil
  if origin and api.nvim_tabpage_is_valid(origin) then api.nvim_set_current_tabpage(origin) end
end

function M.toggle()
  if workspace and api.nvim_tabpage_is_valid(workspace) and api.nvim_get_current_tabpage() == workspace then
    M.close()
  else
    M.open()
  end
end

function M.float(name)
  require "dapui"
  load_project(is_mcu(current()) and current().config.mcu_root or require("mcu").root())
  -- nvim-dap-ui keeps one floating inspector; switch it when a different view is requested.
  for _, win in ipairs(api.nvim_tabpage_list_wins(0)) do
    local buf = api.nvim_win_get_buf(win)
    if
      api.nvim_win_get_config(win).relative ~= ""
      and (vim.bo[buf].filetype == "mcu_debug" or vim.bo[buf].filetype:match "^dapui_")
    then
      api.nvim_win_close(win, true)
    end
  end
  if name == "peripherals" and not stopped() then peripheral_placeholder() end
  local custom = titles[name] ~= nil
  require("dapui").float_element(custom and ("mcu_" .. name) or name, {
    enter = true,
    width = math.max(20, math.min(105, vim.o.columns - 8)),
    height = math.max(6, math.min(30, vim.o.lines - 8)),
    title = custom and titles[name] or name:upper(),
  })
  if custom then
    vim.schedule(function()
      if stopped() then
        sample_memory(state.epoch)
        sample_disassembly(state.epoch)
      end
    end)
  end
end

function M.views()
  vim.ui.select({
    "registers",
    "peripherals",
    "watches",
    "scopes",
    "stacks",
    "breakpoints",
    "memory",
    "disassembly",
    "trace",
    "repl",
  }, { prompt = "STM32 debug view" }, function(choice)
    if choice == "memory" then
      M.memory()
    elseif choice then
      M.float(choice)
    end
  end)
end

function M.memory(expression)
  local function show(value)
    if not value or vim.trim(value) == "" then return end
    state.memory = value
    panes.memory.hint = "32 bytes at " .. clean(value) .. "  |  a address  r refresh"
    put("memory", { "Pause the MCU to read this address." })
    M.float "memory"
  end
  if type(expression) == "string" and expression ~= "" then return show(expression) end
  vim.ui.input({ prompt = "Memory address / pointer expression: ", default = state.memory or "$sp" }, show)
end

function M.add_peripheral(expression)
  load_project(is_mcu(current()) and current().config.mcu_root or require("mcu").root())
  local function add(value)
    if not value or vim.trim(value) == "" then return end
    if #state.peripherals >= 32 then return notify "Up to 32 peripheral watches per project." end
    for _, item in ipairs(state.peripherals) do
      if item.expression == value then return notify "Already watching this expression." end
    end
    table.insert(state.peripherals, { name = value, expression = value })
    save_peripherals()
    peripheral_placeholder()
    if stopped() then M.refresh() end
    if not visible "peripherals" then M.float "peripherals" end
  end
  if type(expression) == "string" and expression ~= "" then return add(expression) end
  vim.ui.input({ prompt = "Peripheral expression (read on each stop; avoid read-to-clear registers): " }, add)
end

function M.remove_peripheral()
  local index = api.nvim_win_get_cursor(0)[1] - 3
  if index < 1 or index > #state.peripherals then return end
  table.remove(state.peripherals, index)
  save_peripherals()
  peripheral_placeholder()
  if stopped() then M.refresh() end
end

function M.watch()
  local word = vim.fn.expand "<cword>"
  vim.ui.input({ prompt = "Watch expression: ", default = word }, function(expression)
    if expression and vim.trim(expression) ~= "" then
      require("dapui").elements.watches.add(expression)
      M.float "watches"
    end
  end)
end

function M.watchpoint()
  if not stopped() then return notify "Pause the MCU before setting a hardware watchpoint." end
  vim.ui.input({ prompt = "Watchpoint expression: ", default = vim.fn.expand "<cword>" }, function(expression)
    if not expression or vim.trim(expression) == "" then return end
    vim.ui.select({ "write", "read", "access" }, { prompt = "Break on memory access" }, function(kind)
      if not kind then return end
      local command = ({ write = "watch", read = "rwatch", access = "awatch" })[kind]
      evaluate(command .. " " .. expression, "repl", function(err, body)
        local message = err and error_text(err) or clean(body.result)
        require("dap").repl.append(message)
        notify(message)
      end)
    end)
  end)
end

function M.logpoint()
  vim.ui.input({ prompt = "Logpoint message (use {expression}): " }, function(message)
    if message and message ~= "" then require("dap").set_breakpoint(nil, nil, message) end
  end)
end

function M.continue()
  if current() then
    require("dap").continue()
  else
    require("mcu").debug()
  end
end

function M.pause()
  if current() then
    require("dap").pause()
  else
    notify "Attach first with Space m d or F5."
  end
end

function M.disconnect()
  if not current() then return end
  require("dap").disconnect { terminateDebuggee = false }
end

function M.export_trace()
  vim.ui.input(
    { prompt = "Save register history: ", default = vim.fn.getcwd() .. "/mcu-trace.txt", completion = "file" },
    function(path)
      if not path or path == "" then return end
      path = vim.fn.expand(path)
      if vim.fn.filereadable(path) == 1 then return notify "File already exists; choose a new filename." end
      local lines = {
        "STM32 halted register history",
        "Project: " .. (state.root or "unknown"),
        "Newest sample first; no continuous SWO trace.",
        "",
      }
      vim.list_extend(lines, state.history)
      local ok, err = pcall(vim.fn.writefile, lines, path)
      notify(ok and ("Saved " .. path) or tostring(err))
    end
  )
end

function M.setup(dapui)
  highlights()
  api.nvim_create_autocmd(
    "ColorScheme",
    { group = api.nvim_create_augroup("mcu_debug_colors", { clear = true }), callback = highlights }
  )
  api.nvim_create_autocmd("BufWinEnter", {
    group = api.nvim_create_augroup("mcu_debug_windows", { clear = true }),
    callback = function(event)
      local ft = vim.bo[event.buf].filetype
      local labels = {
        dapui_scopes = "VARIABLES",
        dapui_watches = "WATCHES",
        dapui_stacks = "CALL STACK",
        dapui_breakpoints = "BREAKPOINTS",
      }
      if ft == "mcu_debug" or labels[ft] then
        vim.wo.statuscolumn = ""
        vim.wo.number, vim.wo.relativenumber = false, false
        vim.wo.signcolumn, vim.wo.foldcolumn = "no", "0"
        vim.wo.wrap, vim.wo.spell = false, false
        vim.wo.winbar = labels[ft] and ("%#MCUHeading# " .. labels[ft] .. "%*") or ""
      end
    end,
  })
  for name in pairs(titles) do
    panes[name] = { hint = name == "peripherals" and "a add  |  dd remove  |  r refresh" or nil }
    dapui.register_element("mcu_" .. name, {
      buffer = function() return buffer(name) end,
      render = function()
        buffer(name)
        draw(name)
      end,
      allow_without_session = true,
    })
  end
  panes.registers.hint = "* changed since last sample  |  r refresh"
  panes.trace.hint = "Newest first  |  C clear  s save  |  max 400 lines"
  panes.disassembly.hint = "At halted PC  |  F7 instruction step  r refresh"
  local dap = require "dap"
  dap.listeners.before.scopes.mcu_workspace = function(session, err, response)
    if is_mcu(session) and not err and response then
      -- GDB includes registers in its variable scopes; they already have their own pane.
      response.scopes = vim.tbl_filter(
        function(scope) return scope.presentationHint ~= "registers" and scope.name ~= "Registers" end,
        response.scopes or {}
      )
    end
  end
  local function finish(session)
    if not is_mcu(session) then return end
    state.status, state.epoch = "disconnected", state.epoch + 1
    M.render()
  end
  dap.listeners.after.event_initialized.mcu_workspace = function(session)
    if not is_mcu(session) then return end
    state.status, state.stop, state.registers, state.history = "attached", 0, {}, {}
    state.epoch, state.frame, state.thread, state.memory = state.epoch + 1, nil, nil, nil
    load_project(session.config.mcu_root or require("mcu").root())
    state.peripheral_values = {}
    session.on_close.mcu_workspace = function()
      vim.schedule(function()
        if not current() or current() == session then finish(session) end
      end)
    end
    for name in pairs(panes) do
      put(name, { "Waiting for a halted target." })
    end
    M.open()
  end
  dap.listeners.after.event_stopped.mcu_workspace = function(session, body)
    if not is_mcu(session) then return end
    state.status, state.reason, state.thread = "stopped", body.reason, body.threadId
    state.stop = state.stop + 1
    M.refresh(true)
    M.render()
  end
  dap.listeners.before.event_continued.mcu_workspace = function(session)
    if not is_mcu(session) then return end
    state.status, state.epoch = "running", state.epoch + 1
    M.render()
  end
  dap.listeners.before.event_terminated.mcu_workspace = finish
  dap.listeners.before.event_exited.mcu_workspace = finish
  dap.listeners.after.disconnect.mcu_workspace = finish
  M.render()
end

return M
