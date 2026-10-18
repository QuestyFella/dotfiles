-- Colorscheme follows the desktop theme set by ~/.local/bin/theme
-- (which also live-switches running Neovim instances).
local function read(name, default)
  local f = io.open(vim.fn.expand("~/.config/themes/current/" .. name), "r")
  if not f then return default end
  local value = vim.trim(f:read("*a"))
  f:close()
  return value ~= "" and value or default
end

vim.o.background = read("mode", "dark")

return {
  -- Colorschemes the theme palettes can ask for (tokyonight ships with LazyVim).
  { "catppuccin/nvim", name = "catppuccin", lazy = true },
  { "ellisonleao/gruvbox.nvim", lazy = true },
  { "gbprod/nord.nvim", lazy = true },
  { "rose-pine/neovim", name = "rose-pine", lazy = true },
  { "rebelot/kanagawa.nvim", lazy = true },
  { "Mofiqul/dracula.nvim", lazy = true },
  { "sainnhe/everforest", lazy = true },
  { "LazyVim/LazyVim", opts = { colorscheme = read("nvim-colorscheme", "tokyonight") } },
}
