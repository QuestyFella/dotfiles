local M = {}

function M.build()
  if not vim.b.vimtex then return end
  if vim.fn.executable("tectonic") == 0 then
    vim.notify("LaTeX needs Tectonic: brew install tectonic", vim.log.levels.ERROR)
    return
  end
  vim.cmd("VimtexCompile")
end

function M.note()
  vim.cmd("enew")
  require("lazy").load({ plugins = { "nvim-lspconfig" } })
  vim.bo.filetype = "tex"
  vim.b.latex_new_note = true
  vim.api.nvim_buf_set_lines(0, 0, -1, false, {
    "\\documentclass[11pt]{article}",
    "\\usepackage[margin=1in]{geometry}",
    "\\usepackage{amsmath,amssymb}",
    "\\usepackage{graphicx}",
    "\\usepackage{hyperref}",
    "\\title{Lecture Notes}",
    "\\author{}",
    "\\date{\\today}",
    "",
    "\\begin{document}",
    "\\maketitle",
    "",
    "\\section{Topic}",
    "",
    "",
    "\\end{document}",
  })
  vim.api.nvim_win_set_cursor(0, { 14, 0 })
  vim.notify("Save with :w path/to/notes.tex to build and preview.")
end

function M.setup()
  vim.api.nvim_create_user_command("LatexNote", M.note, { desc = "New LaTeX lecture note" })
  vim.api.nvim_create_user_command("LatexHelp", function()
    vim.cmd.edit(vim.fn.stdpath("config") .. "/LATEX.md")
  end, { desc = "LaTeX notetaking guide" })
  vim.keymap.set("n", "<leader>jn", M.note, { desc = "New LaTeX note" })
  vim.keymap.set("n", "<leader>jh", "<cmd>LatexHelp<cr>", { desc = "LaTeX guide" })

  local group = vim.api.nvim_create_augroup("LatexNotes", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group,
    pattern = { "tex", "plaintex" },
    callback = function(event)
      vim.opt_local.spell = true
      vim.opt_local.spelllang = { "en" }
      vim.opt_local.wrap = true
      vim.opt_local.linebreak = true
      vim.b.latex_build_on_save = true
      local function map(lhs, rhs, desc)
        vim.keymap.set("n", "<leader>j" .. lhs, rhs, { buffer = event.buf, desc = desc })
      end
      map("b", function()
        local saved_build = vim.bo.modified and vim.b.latex_build_on_save
        vim.cmd.update()
        if not saved_build then M.build() end
      end, "Save and build PDF")
      -- Explicit builds also work when the buffer was already saved.
      map("B", M.build, "Rebuild PDF")
      map("v", "<cmd>VimtexView<cr>", "Preview PDF / jump to cursor")
      map("e", "<cmd>VimtexErrors<cr>", "Build errors")
      map("o", "<cmd>VimtexCompileOutput<cr>", "Compiler output")
      map("t", "<cmd>VimtexTocToggle<cr>", "Table of contents")
      map("i", "<cmd>VimtexInfo<cr>", "LaTeX project info")
      map("a", function()
        vim.b.latex_build_on_save = not vim.b.latex_build_on_save
        vim.notify("LaTeX build on save: " .. (vim.b.latex_build_on_save and "on" or "off"))
      end, "Toggle build on save")
      map("s", "z=", "Spelling suggestions")
      map("c", "1z=", "Correct word (first suggestion)")
      map("w", "zg", "Add word to dictionary")
      map("m", function() vim.snippet.expand("\\[\n\t${1}\n\\]$0") end, "Insert display math")
      map("f", function() vim.snippet.expand("\\frac{${1:numerator}}{${2:denominator}}$0") end, "Insert fraction")
      map("j", "gj", "Next visual line")
      map("k", "gk", "Previous visual line")
    end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group,
    pattern = "*.tex",
    callback = function()
      if vim.b.latex_new_note then
        vim.b.latex_new_note = nil
        -- An unnamed template has no URI for Texlab until its first save.
        vim.lsp.enable("texlab")
      end
      if vim.b.latex_build_on_save then M.build() end
    end,
  })
end

return M
