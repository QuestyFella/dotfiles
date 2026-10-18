return {
  { import = "lazyvim.plugins.extras.lang.tex" },
  {
    "lervag/vimtex",
    tag = "v2.15", -- Supports the installed Neovim; newer releases require 0.12.4.
    init = function()
      vim.g.tex_flavor = "latex"
      vim.g.vimtex_compiler_method = "tectonic"
      vim.g.vimtex_view_method = "skim"
      vim.g.vimtex_view_skim_activate = 0
      vim.g.vimtex_quickfix_open_on_warning = 0
      require("latex").setup()
    end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        texlab = {
          mason = false,
          settings = {
            texlab = {
              build = {
                executable = "tectonic",
                args = { "--keep-logs", "--synctex", "%f" },
                onSave = false, -- VimTeX owns compilation and its error list.
              },
            },
          },
        },
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>j", group = "LaTeX / notes", icon = "󰙩" } } },
  },
}
