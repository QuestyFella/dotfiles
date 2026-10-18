-- Uses real installed cores. Never uploads or opens a hardware port.
-- nvim --headless '+lua dofile(vim.fn.stdpath("config") .. "/tests/arduino.lua")'
local arduino = require "arduino"
local api = vim.api
local base = vim.fn.tempname() .. " arduino tests"
local root = base .. "/SerialCheck"
local fqbn = vim.env.ARDUINO_TEST_FQBN or "arduino:avr:uno"
local function check(value, message) assert(value, message) end
local function wait(label, fn, timeout) check(vim.wait(timeout or 30000, fn, 50), "Timed out: " .. label) end
local function run()
  vim.fn.mkdir(root .. "/src", "p")
  root = vim.uv.fs_realpath(root)
  vim.fn.writefile({ vim.json.encode { fqbn = fqbn, baud = 115200 } }, root .. "/.nvim-arduino.json")
  vim.fn.writefile({
    '#include "src/helper.h"',
    "void setup() { Serial.begin(115200); }",
    "void loop() {",
    '  Serial.println("Neovim Arduino check");',
    "  delay(interval());",
    "}",
  }, root .. "/SerialCheck.ino")
  vim.fn.writefile({ "#pragma once", "unsigned long interval();" }, root .. "/src/helper.h")
  vim.fn.writefile({ '#include "helper.h"', "unsigned long interval() { return 1000; }" }, root .. "/src/helper.cpp")
  check(arduino.detect(root .. "/src/helper.cpp") == root, "Companion source root")
  check(not arduino.detect(base .. "/stm32/main.c"), "STM32 mistaken for Arduino")
  check(not arduino.detect "snacks://picker/input", "Plugin URI mistaken for a file")
  check(
    arduino.build_path(root, "arduino:avr:uno") ~= arduino.build_path(root, "arduino:avr:nano"),
    "Board caches collide"
  )
  check(arduino.build_path(root, fqbn) ~= arduino.build_path(base .. "/Other", fqbn), "Sketch caches collide")
  check(vim.fn.exists ":MCUBuild" == 2 and vim.fn.exists ":ArduinoBuild" == 2, "Mode commands missing")
  vim.o.columns, vim.o.lines = 180, 48
  vim.cmd.edit(vim.fn.fnameescape(root .. "/SerialCheck.ino"))
  local ino = api.nvim_get_current_buf()
  check(vim.bo.filetype == "arduino", "Wrong .ino filetype")
  check(vim.b.autoformat == false, "Automatic formatting changed")
  arduino.workspace()
  check(#api.nvim_list_wins() == 3, "Expected code, panel and output")
  check(api.nvim_get_current_buf() == ino, "Workspace lost source focus")
  arduino.workspace()
  check(#api.nvim_list_wins() == 3, "Workspace duplicated panes")
  arduino.build(false)
  wait("compile", function() return not arduino.status():find("Compile…", 1, true) end, 120000)
  local elf = arduino.build_path(root, fqbn) .. "/SerialCheck.ino.elf"
  check(vim.fn.filereadable(elf) == 1, "Missing compiled firmware: " .. elf)
  print("BUILD_OK " .. fqbn)

  require("lazy").load { plugins = { "nvim-lspconfig" } }
  local client
  wait("Arduino language server", function()
    client = vim.lsp.get_clients({ bufnr = ino, name = "arduino_language_server" })[1]
    return client and client.initialized
  end, 60000)
  check(#vim.lsp.get_clients { bufnr = ino, name = "clangd" } == 0, "Duplicate clangd on sketch")
  local hover
  wait("Serial hover", function()
    local response = client:request_sync("textDocument/hover", {
      textDocument = { uri = vim.uri_from_bufnr(ino) },
      position = { line = 1, character = 18 },
    }, 1500, ino)
    hover = response and response.result
    return hover and hover.contents
  end, 60000)
  print("LSP_HOVER_OK " .. vim.inspect(hover.contents):sub(1, 180))
  vim.wait(800)
  local errors = vim.diagnostic.get(nil, { severity = vim.diagnostic.severity.ERROR })
  check(#errors == 0, "Unexpected diagnostics on valid sketch: " .. vim.inspect(errors))
  print "LSP_CLEAN_DIAGNOSTICS_OK"
  local completion = client:request_sync("textDocument/completion", {
    textDocument = { uri = vim.uri_from_bufnr(ino) },
    position = { line = 1, character = 22 },
    context = { triggerKind = 2, triggerCharacter = "." },
  }, 10000, ino)
  local items = completion and completion.result
  items = items and (items.items or items) or {}
  check(
    vim.iter(items):any(function(item) return item.label:find("begin", 1, true) end),
    "Missing Serial.begin completion"
  )
  print "LSP_COMPLETION_OK"
  vim.cmd.edit(vim.fn.fnameescape(root .. "/src/helper.cpp"))
  local cpp = api.nvim_get_current_buf()
  wait(
    "companion source LSP",
    function() return #vim.lsp.get_clients { bufnr = cpp, name = "arduino_language_server" } == 1 end
  )
  check(#vim.lsp.get_clients { bufnr = cpp, name = "clangd" } == 0, "Duplicate clangd on companion source")
  print "LSP_COMPANION_OK"

  vim.cmd.buffer(ino)
  api.nvim_buf_set_lines(ino, 3, 4, false, { "  definitely_missing_function();" })
  arduino.build(false)
  wait("failed compile", function() return not arduino.status():find("Compile…", 1, true) end, 60000)
  local found = false
  for _, item in ipairs(vim.fn.getqflist()) do
    if item.lnum == 4 and api.nvim_buf_get_name(item.bufnr) == root .. "/SerialCheck.ino" then found = true end
  end
  check(found, "Compiler error did not map to the original .ino line")
  print "ERROR_NAVIGATION_OK"

  -- Selection must retain the captured sketch when the user changes buffers.
  local old_select, select_callback = vim.ui.select
  vim.ui.select = function(items, _, cb)
    select_callback = function()
      for _, item in ipairs(items) do
        if item.fqbn == "arduino:avr:nano:cpu=atmega328old" then
          cb(item)
          return
        end
      end
      error "Nano old bootloader missing"
    end
  end
  arduino.board(root)
  wait("board list", function() return select_callback ~= nil end)
  vim.cmd.enew()
  select_callback()
  vim.ui.select = old_select
  check(arduino.config(root).fqbn == "arduino:avr:nano:cpu=atmega328old", "Board selection saved to wrong sketch")
  print "ASYNC_BOARD_SELECTION_OK"
  print("ARDUINO_CHECKS_PASS " .. fqbn)
end
local ok, err = xpcall(run, debug.traceback)
for _, client in ipairs(vim.lsp.get_clients()) do
  client:stop(true)
end
if not ok then
  io.stderr:write(tostring(err) .. "\n")
  vim.cmd "cquit 1"
else
  vim.cmd "qa!"
end
