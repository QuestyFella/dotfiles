local M = {}
function M.check()
  vim.health.start "MCU development"
  for _, tool in ipairs {
    "cmake",
    "ninja",
    "arm-none-eabi-gcc",
    "arm-none-eabi-gdb-py",
    "arm-none-eabi-size",
    "clangd",
    "clang-format",
    "openocd",
    "STM32_Programmer_CLI",
    "picocom",
  } do
    local path = vim.fn.exepath(tool)
    if path ~= "" then
      vim.health.ok(tool .. ": " .. path)
    else
      vim.health.warn(tool .. " missing")
    end
  end
  local cfg, root = require("mcu").config()
  vim.health.info("Project: " .. root .. "\nBuild: " .. cfg.build_dir)
  if
    vim.fn.filereadable(cfg.build_dir .. "/compile_commands.json") == 1
    or vim.fn.filereadable(root .. "/compile_commands.json") == 1
  then
    vim.health.ok "Compilation database found"
  else
    vim.health.warn "No compilation database. Run :MCUConfigure inside a CMake project."
  end
  vim.health.start "STM32 debug workspace"
  local ok, dapui = pcall(require, "dapui")
  if ok and dapui.elements.mcu_registers then
    vim.health.ok "Register, peripheral, memory, disassembly and history panes loaded"
  else
    vim.health.error("Debug UI unavailable: " .. tostring(dapui))
  end
  if cfg.openocd_target then
    vim.health.info("OpenOCD target: " .. cfg.openocd_target .. "\nGDB: " .. cfg.gdb_target)
  else
    vim.health.info "Set openocd_target in .nvim-mcu.json to use :MCUServer; an external GDB server also works."
  end
  vim.health.info "Register history samples halted targets; SWO/ITM streaming and SVD decoding are not configured."
end
return M
