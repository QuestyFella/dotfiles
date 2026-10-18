return {
  { import = "lazyvim.plugins.extras.lang.r" },
  {
    "R-nvim/R.nvim",
    opts = {
      user_maps_only = true,
      hook = {
        on_filetype = function() require("rnotes").buffer_setup(0) end,
      },
    },
    init = function() require("rnotes").setup() end,
  },
  {
    "neovim/nvim-lspconfig",
    opts = {
      servers = {
        r_language_server = {
          mason = false,
          root_dir = function(bufnr, on_dir)
            local name = vim.api.nvim_buf_get_name(bufnr)
            if name == "" then return end
            on_dir(vim.fs.root(bufnr, { ".Rproj", "DESCRIPTION", "_quarto.yml", ".git" }) or vim.fs.dirname(name))
          end,
        },
      },
    },
  },
  {
    "folke/which-key.nvim",
    opts = { spec = { { "<leader>v", group = "R / notes", mode = { "n", "x" } } } },
  },
}
