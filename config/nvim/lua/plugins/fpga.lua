return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = { ensure_installed = { "systemverilog" } },
  },
  {
    "neovim/nvim-lspconfig",
    opts = { servers = { verible = {} } },
  },
  {
    "mfussenegger/nvim-lint",
    opts = {
      linters_by_ft = {
        systemverilog = { "verilator" },
        verilog = { "verilator" },
      },
      linters = {
        verilator = {
          args = {
            "-sv",
            "-Wall",
            "--bbox-sys",
            "--bbox-unsup",
            "--lint-only",
            "rtl/q16_pkg.sv",
            "rtl/sig_lut_pkg.sv",
            "rtl/xor_net.sv",
          },
        },
      },
    },
  },
  {
    "LazyVim/LazyVim",
    keys = {
      { "<leader>cb", "<cmd>make<cr>", desc = "Build project" },
      { "<leader>co", "<cmd>copen<cr>", desc = "Open build errors" },
    },
  },
}
