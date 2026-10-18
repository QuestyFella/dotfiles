-- Run with the normal configuration:
-- nvim --headless '+lua dofile(vim.fn.stdpath("config") .. "/tests/mcu_debug.lua")'
-- Builds a temporary Cortex-M4 image and uses QEMU only. No probe or board is accessed.
local api = vim.api
local dap = require "dap"
local debug = require "mcu.debug"
local emulator
local root = vim.fn.tempname() .. "-mcu-debug-test"
local port = tonumber(vim.env.MCU_TEST_PORT) or 54334
local function fixture()
  for _, tool in ipairs { "arm-none-eabi-gcc", "arm-none-eabi-gdb-py", "qemu-system-arm" } do
    assert(vim.fn.executable(tool) == 1, "Test dependency missing: " .. tool)
  end
  vim.fn.mkdir(root, "p")
  root = vim.uv.fs_realpath(root)
  vim.fn.writefile(
    vim.split(
      [[typedef unsigned int uint32_t;
volatile uint32_t counter;
volatile uint32_t status;
void Reset_Handler(void);
__attribute__((section(".isr_vector"), used))
const void *vectors[] = { (void *)0x20010000, Reset_Handler };
__attribute__((noinline)) void tick(void) {
  counter++;
  status = counter ^ 0xa5;
  __asm volatile("nop");
}
void Reset_Handler(void) {
  counter = 0;
  status = 0;
  for (;;) {
    tick();
  }
}]],
      "\n"
    ),
    root .. "/main.c"
  )
  vim.fn.writefile(
    vim.split(
      [[ENTRY(Reset_Handler)
MEMORY {
  FLASH (rx) : ORIGIN = 0x08000000, LENGTH = 512K
  RAM (rwx) : ORIGIN = 0x20000000, LENGTH = 64K
}
SECTIONS {
  .text : { KEEP(*(.isr_vector)) *(.text*) *(.rodata*) } > FLASH
  .bss : { *(.bss*) *(COMMON) } > RAM
}]],
      "\n"
    ),
    root .. "/link.ld"
  )
  vim.fn.writefile({
    vim.json.encode {
      build_system = "make",
      elf = "test.elf",
      gdb_target = "127.0.0.1:" .. port,
      peripheral_watches = {
        { name = "Test counter", expression = "counter" },
        { name = "Test status", expression = "status" },
      },
    },
  }, root .. "/.nvim-mcu.json")
  local build = vim
    .system({
      "arm-none-eabi-gcc",
      "-mcpu=cortex-m4",
      "-mthumb",
      "-g3",
      "-O0",
      "-nostdlib",
      "-T",
      "link.ld",
      "main.c",
      "-o",
      "test.elf",
    }, { cwd = root, text = true })
    :wait()
  assert(build.code == 0, build.stderr)
  vim.cmd.cd(vim.fn.fnameescape(root))
end
local function wait_for(label, fn) assert(vim.wait(10000, fn, 20), "Timed out: " .. label) end
local function text(name)
  local buf = vim.fn.bufnr("mcu-debug://" .. name)
  return buf < 0 and "" or table.concat(api.nvim_buf_get_lines(buf, 0, -1, false), "\n")
end
local function close_floats()
  for _, win in ipairs(api.nvim_list_wins()) do
    if api.nvim_win_get_config(win).relative ~= "" then api.nvim_win_close(win, true) end
  end
  vim.wait(50)
end
local function evaluate(command)
  local done, result, failure = false
  dap.session():request("evaluate", { expression = command, context = "repl" }, function(err, body)
    failure, result, done = err, body and body.result, true
  end)
  wait_for(command, function() return done end)
  assert(not failure, vim.inspect(failure))
  return result
end
local function run()
  fixture()
  emulator = vim.fn.jobstart {
    "qemu-system-arm",
    "-M",
    "netduinoplus2",
    "-kernel",
    root .. "/test.elf",
    "-S",
    "-gdb",
    "tcp:127.0.0.1:" .. port,
    "-display",
    "none",
    "-serial",
    "none",
    "-monitor",
    "none",
  }
  assert(emulator > 0)
  vim.wait(300)
  vim.o.columns, vim.o.lines = 200, 55
  vim.cmd.edit(root .. "/main.c")
  require "dapui"
  dap.set_log_level "TRACE"
  require("mcu").debug()
  wait_for(
    "initial registers",
    function()
      return text("registers"):find "r0" and text("trace"):find "#001" and text("peripherals"):find "Test counter = 0x0"
    end
  )
  assert(debug.status() == "MCU STOPPED", debug.status())
  assert(text("peripherals"):find "Test counter = 0x0", text "peripherals")
  assert(#api.nvim_list_tabpages() == 2)
  assert(#api.nvim_tabpage_list_wins(0) == 9)
  assert(require("mcu").root() == root, require("mcu").root())
  print "ARM_GDB_ATTACH_REGISTERS_OK"

  api.nvim_win_set_cursor(0, { 9, 0 })
  dap.toggle_breakpoint()
  vim.wait(100)
  dap.continue()
  wait_for(
    "breakpoint",
    function() return text("trace"):find "#002" and text("peripherals"):find "Test counter = 0x1" end
  )
  assert(text("registers"):find "*", text "registers")
  assert(text("trace"):find " -> ", text "trace")
  print "BREAKPOINT_REGISTER_DIFF_HISTORY_OK"

  dap.step_over()
  wait_for("step", function() return text("trace"):find "#003" and text("peripherals"):find "Test status = 0xa4" end)
  assert(text("trace"):find("Test status: 0x0 -> 0xa4", 1, true), text "trace")
  print "SOURCE_STEP_PERIPHERAL_DIFF_OK"

  debug.memory "&counter"
  wait_for("memory", function() return text("memory"):find "0x01" end)
  assert(text("memory"):find "0x20000000", text "memory")
  debug.float "disassembly"
  wait_for("disassembly", function() return text("disassembly"):find "0x0800" or text("disassembly"):find "0x800" end)
  assert(not text("disassembly"):find "No halted", text "disassembly")
  assert(api.nvim_buf_get_name(0) == "mcu-debug://disassembly", api.nvim_buf_get_name(0))
  close_floats()
  dap.step_into { granularity = "instruction" }
  wait_for("instruction step", function() return text("trace"):find "#004" end)
  print "MEMORY_DISASSEMBLY_INSTRUCTION_STEP_OK"

  local session, delayed = dap.session(), nil
  local original_request = session.request
  session.request = function(self, command, args, callback)
    if command == "evaluate" and args.expression == "info registers" and not delayed then
      return original_request(self, command, args, function(err, body)
        delayed = function() callback(err, { result = "r0 0xdeadbeef stale" }) end
      end)
    end
    return original_request(self, command, args, callback)
  end
  debug.refresh()
  wait_for("deferred response", function() return delayed ~= nil end)
  session.request = original_request
  dap.step_into { granularity = "instruction" }
  wait_for("next sample", function() return text("trace"):find "#005" end)
  delayed()
  assert(not text("registers"):find "deadbeef", text "registers")
  print "STALE_RESPONSE_REJECTED_OK"

  evaluate "watch counter"
  assert(evaluate("info breakpoints"):find "hw watchpoint")
  print "GDB_HARDWARE_WATCHPOINT_OK"
  debug.disconnect()
  wait_for("disconnect", function() return dap.session() == nil and debug.status() == "MCU DISCONNECTED" end)
  assert(text("trace"):find "#005")
  assert(text("registers"):find "DISCONNECTED")
  debug.float "peripherals"
  assert(text("peripherals"):find "Test counter = 0x1", text "peripherals")
  close_floats()
  debug.close()
  assert(#api.nvim_list_tabpages() == 1)
  print "DISCONNECT_RETAIN_SAMPLES_RESTORE_TAB_OK"

  for _, dimensions in ipairs { { 140, 42, 5 }, { 90, 28, 3 } } do
    vim.o.columns, vim.o.lines = dimensions[1], dimensions[2]
    debug.open()
    assert(#api.nvim_tabpage_list_wins(0) == dimensions[3], vim.inspect(dimensions))
    debug.close()
  end
  print "COMPACT_LAYOUTS_OK"
  vim.fn.mkdir(root .. "/other", "p")
  vim.fn.writefile({ "{}" }, root .. "/other/.nvim-mcu.json")
  vim.cmd.edit(root .. "/other/main.c")
  debug.open()
  assert(require("mcu").root() == root .. "/other")
  assert(not text("registers"):find "r0", text "registers")
  assert(not text("trace"):find "#005", text "trace")
  debug.close()
  assert(require("mcu").root() == root .. "/other")
  print "PROJECT_STATE_ISOLATION_OK"
end
vim.schedule(function()
  local ok, err = xpcall(run, _G.debug.traceback)
  if emulator then vim.fn.jobstop(emulator) end
  if not ok then
    print(err)
    pcall(function()
      if dap.session() then dap.disconnect { terminateDebuggee = false } end
    end)
    vim.wait(300)
    vim.cmd "cquit 1"
  else
    print "MCU_EMULATOR_INTEGRATION_OK"
    vim.fn.delete(root, "rf")
    vim.cmd "qa!"
  end
end)
vim.wait(120000, function() return false end, 100)
