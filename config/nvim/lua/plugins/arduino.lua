return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers.arduino_language_server = {
        mason = false,
        filetypes = { "arduino", "c", "cpp" },
        root_dir = function(buf, on_dir)
          local arduino = require "arduino"
          local root = arduino.detect(vim.api.nvim_buf_get_name(buf))
          if root and arduino.config(root).fqbn then on_dir(root) end
        end,
        cmd = function(dispatchers, config)
          local fqbn = require("arduino").config(config.root_dir).fqbn
          local clangd = fqbn:match "^esp32:" and vim.fn.expand "~/.local/share/arduino-tools/esp-clangd/bin/clangd"
            or vim.fn.exepath "clangd"
          return vim.lsp.rpc.start({
            vim.fn.expand "~/.local/bin/arduino-language-server",
            "-cli",
            vim.fn.exepath "arduino-cli",
            "-clangd",
            clangd,
            "-cli-config",
            vim.fn.expand "~/Library/Arduino15/arduino-cli.yaml",
            "-fqbn",
            fqbn,
          }, dispatchers, { cwd = config.root_dir })
        end,
        capabilities = { offsetEncoding = { "utf-16" } },
      }
      -- Sketch companion .cpp/.h files belong to the Arduino server too.
      opts.servers.clangd = opts.servers.clangd or {}
      opts.servers.clangd.root_dir = function(buf, on_dir)
        local file = vim.api.nvim_buf_get_name(buf)
        if require("arduino").detect(file) then return end
        on_dir(
          vim.fs.root(
            file,
            { ".nvim-mcu.json", "CMakePresets.json", "compile_commands.json", "CMakeLists.txt", "Makefile", ".git" }
          ) or vim.fs.dirname(file)
        )
      end
    end,
  },
  { "stevearc/conform.nvim", opts = { formatters_by_ft = { arduino = { "clang_format" } } } },
  { "folke/which-key.nvim", opts = { spec = { { "<leader>a", group = "Arduino / ESP32" } } } },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 1, {
        function() return require("arduino").status() end,
        color = { fg = "#9ece6a" },
      })
    end,
  },
  {
    "LazyVim/LazyVim",
    -- Arduino setup is in init.lua so the existing MCU plugin init remains intact.
    keys = {
      { "<leader>aa", "<cmd>Arduino<cr>", desc = "Arduino actions" },
      { "<leader>ab", "<cmd>ArduinoBoard<cr>", desc = "Select board" },
      { "<leader>ao", "<cmd>ArduinoOptions<cr>", desc = "Board options / bootloader" },
      { "<leader>ap", "<cmd>ArduinoPort<cr>", desc = "Select serial port" },
      { "<leader>ac", "<cmd>ArduinoBuild<cr>", desc = "Compile sketch" },
      { "<leader>au", "<cmd>ArduinoUpload<cr>", desc = "Build + upload sketch" },
      { "<leader>as", "<cmd>ArduinoSerial<cr>", desc = "Serial monitor" },
      { "<leader>aS", "<cmd>ArduinoSerialClose<cr>", desc = "Close serial monitor" },
      { "<leader>ar", "<cmd>ArduinoBaud<cr>", desc = "Serial baud rate" },
      { "<leader>aw", "<cmd>ArduinoWorkbench<cr>", desc = "Arduino workspace" },
      { "<leader>ae", "<cmd>ArduinoOutput<cr>", desc = "Build output" },
      { "<leader>ak", "<cmd>ArduinoStop<cr>", desc = "Stop Arduino task" },
      { "<leader>al", "<cmd>ArduinoLibrary<cr>", desc = "Find + install library" },
      { "<leader>an", "<cmd>ArduinoNew<cr>", desc = "New sketch" },
      { "<leader>ai", "<cmd>ArduinoSettings<cr>", desc = "Sketch settings" },
      { "<leader>aR", "<cmd>ArduinoRestart<cr>", desc = "Restart Arduino language server" },
      { "<leader>ah", "<cmd>ArduinoHelp<cr>", desc = "Arduino guide" },
      { "<leader>aH", "<cmd>ArduinoHealth<cr>", desc = "Arduino health check" },
    },
  },
}
