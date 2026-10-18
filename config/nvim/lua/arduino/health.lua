local M = {}
function M.check()
  vim.health.start "Arduino / ESP32"
  for _, executable in ipairs {
    "arduino-cli",
    vim.fn.expand "~/.local/bin/arduino-language-server",
    "clangd",
    vim.fn.expand "~/.local/share/arduino-tools/esp-clangd/bin/clangd",
  } do
    if vim.fn.executable(executable) == 1 then
      vim.health.ok(executable .. ": " .. vim.fn.exepath(executable))
    else
      vim.health.error("Missing " .. executable)
    end
  end
  local headers = vim.fn.expand "~/.local/share/arduino-tools/esp-clangd/lib/clang/22/include/stdbool.h"
  if vim.fn.filereadable(headers) == 1 then
    vim.health.ok "ESP32 clangd builtin headers present"
  else
    vim.health.error "ESP32 clangd builtin headers missing"
  end
  if vim.fn.executable "arduino-cli" == 1 then
    local result = vim.system({ "arduino-cli", "core", "list", "--json" }, { text = true }):wait(10000)
    local ok, data = pcall(vim.json.decode, result.stdout or "")
    if result.code == 0 and ok then
      for _, p in ipairs(data.platforms or {}) do
        vim.health.ok(p.id .. " " .. (p.installed_version or ""))
      end
    else
      vim.health.warn(result.stderr or "Could not list board cores")
    end
  end
  local root = require("arduino").root()
  if root then
    local cfg = require("arduino").config(root)
    vim.health.info("Sketch: " .. root)
    if cfg.fqbn then
      vim.health.ok("Board: " .. cfg.fqbn)
    else
      vim.health.warn "Select a board with :ArduinoBoard"
    end
    vim.health.info("Port: " .. (cfg.port or "not selected") .. "; baud: " .. cfg.baud)
  else
    vim.health.info "Open Sketch/Sketch.ino or use :ArduinoNew to select a project"
  end
end
return M
