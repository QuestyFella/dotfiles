local function debug_action(name, ...)
  local args = { ... }
  return function()
    require "dapui"
    require("mcu.debug")[name](unpack(args))
  end
end

return {
  { "jay-babu/mason-nvim-dap.nvim", opts = { automatic_installation = false } },
  {
    "mason-org/mason.nvim",
    opts = function(_, opts)
      opts.ensure_installed = vim.tbl_filter(function(tool) return tool ~= "codelldb" end, opts.ensure_installed or {})
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers.clangd = vim.tbl_deep_extend("force", opts.servers.clangd or {}, {
        mason = false,
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=never",
          "--completion-style=detailed",
          "--query-driver=/Applications/ArmGNUToolchain/*/arm-none-eabi/bin/arm-none-eabi-*,/opt/homebrew/bin/arm-none-eabi-*,/opt/homebrew/bin/riscv64-elf-*",
        },
        root_markers = {
          ".nvim-mcu.json",
          "CMakePresets.json",
          "compile_commands.json",
          "CMakeLists.txt",
          "Makefile",
          ".git",
        },
        before_init = function(params, config)
          local cfg = require("mcu").config(config.root_dir)
          if vim.fn.filereadable(cfg.build_dir .. "/compile_commands.json") == 1 then
            config.init_options =
              vim.tbl_extend("force", config.init_options or {}, { compilationDatabasePath = cfg.build_dir })
            params.initializationOptions = config.init_options
          end
        end,
      })
    end,
  },
  {
    "stevearc/conform.nvim",
    opts = {
      formatters_by_ft = { c = { "clang_format" }, cpp = { "clang_format" } },
      formatters = {
        clang_format = { prepend_args = { "--fallback-style=LLVM" } },
      },
    },
  },
  { "nvim-treesitter/nvim-treesitter", opts = { ensure_installed = { "c", "cpp", "cmake", "make", "json", "asm" } } },
  {
    "mfussenegger/nvim-dap",
    opts = function()
      require("dap").configurations.c = {}
      require("dap").configurations.cpp = {}
      require("dap").adapters.mcu_gdb =
        { type = "executable", command = "arm-none-eabi-gdb-py", args = { "--interpreter=dap", "--quiet", "--nx" } }
    end,
  },
  {
    "rcarriga/nvim-dap-ui",
    opts = {
      layouts = {
        {
          position = "left",
          size = 34,
          elements = {
            { id = "scopes", size = 0.35 },
            { id = "watches", size = 0.25 },
            { id = "stacks", size = 0.22 },
            { id = "breakpoints", size = 0.18 },
          },
        },
        {
          position = "right",
          size = 44,
          elements = {
            { id = "mcu_registers", size = 0.68 },
            { id = "mcu_peripherals", size = 0.32 },
          },
        },
        {
          position = "bottom",
          size = 11,
          elements = {
            { id = "repl", size = 0.5 },
            { id = "mcu_trace", size = 0.5 },
          },
        },
      },
      floating = { border = "rounded", max_width = 0.9, max_height = 0.85, mappings = { close = { "q", "<Esc>" } } },
      controls = { enabled = true, element = "repl" },
      render = { max_value_lines = 3, max_type_length = 0 },
    },
    config = function(_, opts)
      local dap, dapui = require "dap", require "dapui"
      dapui.setup(opts)
      require("mcu.debug").setup(dapui)
      -- MCU sessions keep their last sample visible after disconnecting.
      dap.listeners.after.event_initialized.dapui_config = function(session)
        if session.config.type ~= "mcu_gdb" then dapui.open() end
      end
      dap.listeners.before.event_terminated.dapui_config = function(session)
        if session.config.type ~= "mcu_gdb" then dapui.close() end
      end
      dap.listeners.before.event_exited.dapui_config = dap.listeners.before.event_terminated.dapui_config
    end,
    keys = { { "<leader>du", debug_action "toggle", desc = "STM32 debug workspace" } },
  },
  {
    "theHamsta/nvim-dap-virtual-text",
    opts = { commented = true, highlight_changed_variables = true, only_first_definition = true, virt_text_pos = "eol" },
  },
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      table.insert(opts.sections.lualine_x, 1, {
        function() return package.loaded["mcu.debug"] and require("mcu.debug").status() or "" end,
        color = function()
          local stopped = package.loaded["mcu.debug"] and require("mcu.debug").status():find "STOPPED"
          return { fg = stopped and "#e0af68" or "#7dcfff", gui = "bold" }
        end,
      })
    end,
  },
  { "folke/which-key.nvim", opts = { spec = { { "<leader>m", group = "MCU / STM32" } } } },
  {
    "LazyVim/LazyVim",
    init = function() require("mcu").setup() end,
    keys = {
      { "<leader>mc", "<cmd>MCUConfigure<cr>", desc = "Configure + index" },
      { "<leader>mb", "<cmd>MCUBuild<cr>", desc = "Build firmware" },
      { "<leader>mp", "<cmd>MCUPreset<cr>", desc = "Select CMake preset" },
      { "<leader>mf", "<cmd>MCUFlash<cr>", desc = "Flash with ST-LINK" },
      { "<leader>mo", "<cmd>MCUServer<cr>", desc = "OpenOCD server" },
      { "<leader>md", "<cmd>MCUDebug<cr>", desc = "Attach MCU debugger" },
      { "<leader>ms", "<cmd>MCUSerial<cr>", desc = "Serial monitor" },
      { "<leader>mz", "<cmd>MCUSize<cr>", desc = "Firmware sections/size" },
      { "<leader>mi", "<cmd>MCUInit<cr>", desc = "Project MCU settings" },
      { "<leader>mk", "<cmd>MCUStop<cr>", desc = "Stop build task" },
      { "<leader>mh", "<cmd>MCUHelp<cr>", desc = "MCU guide" },
      { "<leader>mH", "<cmd>MCUHealth<cr>", desc = "MCU health check" },
      { "<leader>mu", debug_action "toggle", desc = "Debug workspace" },
      { "<leader>mv", debug_action "views", desc = "Debug view picker" },
      { "<leader>mr", debug_action("float", "registers"), desc = "CPU registers" },
      { "<leader>mP", debug_action("float", "peripherals"), desc = "Peripheral watches" },
      { "<leader>mM", debug_action "memory", desc = "Memory inspector" },
      { "<leader>ma", debug_action("float", "disassembly"), desc = "Disassembly at PC" },
      { "<leader>mt", debug_action("float", "trace"), desc = "Register change history" },
      { "<leader>mw", debug_action "watch", desc = "Add variable watch" },
      { "<leader>mW", debug_action "watchpoint", desc = "Memory watchpoint" },
      { "<leader>ml", debug_action "logpoint", desc = "Logpoint" },
      { "<leader>mR", debug_action "refresh", desc = "Refresh halted target" },
      { "<leader>mq", debug_action "disconnect", desc = "Disconnect debugger" },
      { "<F5>", debug_action "continue", desc = "Attach / continue MCU" },
      { "<S-F5>", debug_action "disconnect", desc = "Disconnect debugger" },
      { "<F6>", debug_action "pause", desc = "Pause MCU" },
      { "<F7>", function() require("dap").step_into { granularity = "instruction" } end, desc = "Step instruction" },
      { "<F8>", function() require("dap").run_to_cursor() end, desc = "Run to cursor" },
      { "<F9>", function() require("dap").toggle_breakpoint() end, desc = "Breakpoint" },
      { "<F10>", function() require("dap").step_over() end, desc = "Step over" },
      { "<F11>", function() require("dap").step_into() end, desc = "Step into" },
      { "<F12>", function() require("dap").step_out() end, desc = "Step out" },
      { "<S-F11>", function() require("dap").step_out() end, desc = "Step out" },
    },
  },
}
