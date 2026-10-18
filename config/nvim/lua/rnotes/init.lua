local M = {}
local renders = {}
local last_log = {}
local output_buffers = {}

local function document(buf)
  local file = vim.api.nvim_buf_get_name(buf)
  if file == "" then
    vim.notify("Save the note as a .qmd or .Rmd file first.", vim.log.levels.WARN)
    return
  end
  if not file:lower():match("%.qmd$") and not file:lower():match("%.rmd$") then
    vim.notify("PDF rendering is for .qmd / .Rmd notes. Use Space v n to create one.", vim.log.levels.WARN)
    return
  end
  return vim.uv.fs_realpath(file) or file
end

local function output_path(file, format)
  return file:gsub("%.[^.]+$", "." .. format)
end

function M.view(file)
  file = file or document(0)
  if not file then return end
  local pdf = output_path(file, "pdf")
  if vim.fn.filereadable(pdf) == 0 then
    vim.notify("Render the PDF first with Space v b.", vim.log.levels.WARN)
    return
  end
  vim.system({ "open", "-a", "Skim", pdf }, {}, function(result)
    if result.code ~= 0 then
      vim.schedule(function() vim.notify(result.stderr, vim.log.levels.ERROR) end)
    end
  end)
end

function M.render(buf, format, preview)
  buf = buf == 0 and vim.api.nvim_get_current_buf() or (buf or vim.api.nvim_get_current_buf())
  format = format or "pdf"
  local file = document(buf)
  if not file then return end
  if vim.fn.executable("quarto") == 0 then
    vim.notify("R notes need Quarto: brew install --cask quarto", vim.log.levels.ERROR)
    return
  end
  if renders[file] then
    -- Queue the latest saved version so a save during rendering is not lost.
    renders[file].pending = { buf = buf, format = format, preview = preview }
    return
  end
  local cmd = {
    "quarto", "render", file, "--to", format, "--output", vim.fs.basename(output_path(file, format)),
    "--output-dir", ".",
  }
  if format == "pdf" then
    vim.list_extend(cmd, { "--pdf-engine", "tectonic", "-M", "latex-auto-mk:false" })
  end
  local state = {}
  renders[file] = state
  vim.notify("Rendering R note to " .. format .. "…")
  state.process = vim.system(cmd, { cwd = vim.fs.dirname(file), text = true }, function(result)
    vim.schedule(function()
      last_log[file] = vim.split((result.stdout or "") .. (result.stderr or ""), "\n", { plain = true })
      renders[file] = nil
      local pending = state.pending
      if result.code == 0 then
        vim.notify("R note rendered: " .. vim.fs.basename(output_path(file, format)))
        if preview then
          if format == "pdf" then M.view(file) else vim.ui.open(output_path(file, format)) end
        end
      else
        vim.notify("R note render failed. Space v o shows the log.", vim.log.levels.ERROR)
      end
      if pending and vim.api.nvim_buf_is_valid(pending.buf) then
        M.render(pending.buf, pending.format, pending.preview)
      end
    end)
  end)
end

function M.build(format)
  format = format or "pdf"
  if not document(0) then return end
  local buf = vim.api.nvim_get_current_buf()
  local auto = vim.b.rnotes_build_on_save
  -- The explicit build owns this save, avoiding a duplicate auto render.
  vim.b.rnotes_build_on_save = false
  local ok, err = pcall(vim.cmd.update)
  vim.b.rnotes_build_on_save = auto
  if not ok then vim.notify(tostring(err), vim.log.levels.ERROR); return end
  M.render(buf, format, true)
end

function M.log()
  local file = document(0)
  if not file then return end
  if not last_log[file] then
    vim.notify("No render log yet. Render this note first.")
    return
  end
  local buf = output_buffers[file]
  if not buf or not vim.api.nvim_buf_is_valid(buf) then
    buf = vim.api.nvim_create_buf(false, true)
    output_buffers[file] = buf
    vim.bo[buf].buftype = "nofile"
    vim.bo[buf].bufhidden = "wipe"
    vim.bo[buf].swapfile = false
    vim.bo[buf].filetype = "log"
    vim.keymap.set("n", "q", "<cmd>close<cr>", { buffer = buf })
  end
  vim.bo[buf].modifiable = true
  vim.api.nvim_buf_set_lines(buf, 0, -1, false, last_log[file])
  vim.bo[buf].modifiable = false
  vim.cmd("botright 12split")
  vim.api.nvim_win_set_buf(0, buf)
end

function M.note()
  vim.cmd("enew")
  require("lazy").load({ plugins = { "nvim-lspconfig" } })
  vim.bo.filetype = "quarto"
  vim.b.rnotes_new_note = true
  local template = vim.fn.stdpath("config") .. "/templates/r-notes.qmd"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, vim.fn.readfile(template))
  vim.api.nvim_win_set_cursor(0, { 16, 0 })
  vim.notify("Save with :w path/to/notes.qmd, then Space v b to render and preview.")
end

function M.buffer_setup(buf)
  buf = buf == 0 and vim.api.nvim_get_current_buf() or buf
  local ft = vim.bo[buf].filetype
  if not vim.tbl_contains({ "r", "rmd", "quarto" }, ft) then return end
  local function map(key, rhs, desc, mode)
    vim.keymap.set(mode or "n", "<leader>v" .. key, rhs, { buffer = buf, desc = desc })
  end
  map("r", "<Plug>RStart", "Start / show R console")
  map("l", "<Plug>RDSendLine", "Run R line and move down")
  map("l", "<Plug>RSendSelection", "Run selected R code", "x")
  if ft == "r" then map("f", "<Plug>RSendFile", "Run R script") end
  map("q", function() require("r.run").quit_R("nosave") end, "Quit R console")
  map("d", "<Plug>ROBToggle", "R object browser")
  if ft ~= "r" then
    vim.api.nvim_buf_call(buf, function()
      vim.opt_local.spell = true
      vim.opt_local.spelllang = { "en" }
      vim.opt_local.wrap = true
      vim.opt_local.linebreak = true
    end)
    if vim.b[buf].rnotes_build_on_save == nil then vim.b[buf].rnotes_build_on_save = true end
    map("b", function() M.build("pdf") end, "Render PDF and preview")
    map("v", function() M.view() end, "View PDF in Skim")
    map("H", function() M.build("html") end, "Render HTML and preview")
    map("a", function()
      vim.b.rnotes_build_on_save = not vim.b.rnotes_build_on_save
      vim.notify("R note render on save: " .. (vim.b.rnotes_build_on_save and "on" or "off"))
    end, "Toggle PDF render on save")
    map("o", M.log, "Render log")
    map("c", "<Plug>RSendChunk", "Run current R chunk")
    map("s", "z=", "Spelling suggestions")
    map("w", "zg", "Add word to dictionary")
    map("i", function() vim.snippet.expand("```{r}\n${1}\n```\n$0") end, "Insert R code chunk")
  end
end

function M.setup()
  vim.filetype.add({ extension = { qmd = "quarto", Rmd = "rmd" } })
  vim.api.nvim_create_user_command("RNote", M.note, { desc = "New R / Quarto note" })
  vim.api.nvim_create_user_command("RNotesHelp", function()
    vim.cmd.edit(vim.fn.stdpath("config") .. "/R-NOTES.md")
  end, { desc = "R notes guide" })
  vim.keymap.set("n", "<leader>vn", M.note, { desc = "New R note" })
  vim.keymap.set("n", "<leader>vh", "<cmd>RNotesHelp<cr>", { desc = "R notes guide" })
  local group = vim.api.nvim_create_augroup("RNotes", { clear = true })
  vim.api.nvim_create_autocmd("FileType", {
    group = group, pattern = { "r", "rmd", "quarto" },
    callback = function(event) M.buffer_setup(event.buf) end,
  })
  vim.api.nvim_create_autocmd("BufWritePost", {
    group = group, pattern = { "*.qmd", "*.Rmd", "*.rmd" },
    callback = function(event)
      if vim.b[event.buf].rnotes_new_note then
        vim.b[event.buf].rnotes_new_note = nil
        vim.lsp.enable("r_language_server")
      end
      if vim.b[event.buf].rnotes_build_on_save then M.render(event.buf, "pdf", true) end
    end,
  })
end

return M
