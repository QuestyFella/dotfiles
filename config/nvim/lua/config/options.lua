-- LazyVim loads this before plugin startup.
vim.g.mapleader = " "
vim.g.maplocalleader = ","

vim.opt.relativenumber = true
vim.opt.number = true
vim.opt.wrap = false
vim.opt.signcolumn = "yes"

-- Prefer the complete Arm toolchain and upstream LLVM inside Neovim.
local arm = vim.fn.glob("/Applications/ArmGNUToolchain/*/arm-none-eabi/bin", false, true)
table.sort(arm)
local paths = { vim.fn.expand("~/.local/bin"), "/opt/homebrew/opt/llvm/bin" }
if #arm > 0 then table.insert(paths, 1, arm[#arm]) end
vim.env.PATH = table.concat(paths, ":") .. ":" .. vim.env.PATH
vim.opt.updatetime = 250
vim.opt.scrolloff = 6
vim.opt.splitright = true
vim.opt.splitbelow = true
