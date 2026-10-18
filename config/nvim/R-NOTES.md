# R notes in Neovim

Open `.R`, `.Rmd`, or `.qmd` files to use the R menu under **Space v**.
Run `:RNote` or **Space v n** for a new Quarto note with prose, equations,
executable R chunks, and a sample plot. Save as `notes.qmd` to render its PDF.
Quarto, R, and Tectonic generate the document; Skim displays it.

Saving `.qmd` / `.Rmd` notes renders their PDF and opens it in Skim. Keep Skim
beside Neovim; file-change detection and automatic reload are enabled in Skim.
**Space v a** toggles rendering on save for the current buffer.
Rendering executes the document's R chunks. Each render has a fresh R session;
the interactive console's variables are separate, so define dependencies in
the document itself. First renders may download TeX packages.

| Shortcut | Action |
| --- | --- |
| Space v n | New R / Quarto note |
| Space v h | This guide |
| Space v r | Start or show R console |
| Space v l | Run current R line and move down |
| Space v l (visual mode) | Run selected R code |
| Space v f (`.R`) | Run entire R script |
| Space v c (notes) | Run current R chunk |
| Space v d | Toggle R object browser |
| Space v q | Quit R console without saving its workspace |
| Space v b | Save, render PDF, and preview |
| Space v v | View existing PDF |
| Space v a | Toggle PDF rendering on save |
| Space v H | Render and open HTML |
| Space v o | Show most recent render log; `q` closes it |
| Space v i | Insert an R chunk snippet |
| Space v s | Spelling suggestions in note prose |
| Space v w | Add word to personal dictionary |

Start R with **Space v r** before sending lines, selections, or chunks.
The console appears inside Neovim. Press Esc to leave its terminal input mode;
`i` resumes input. R.nvim provides chunk execution and an object browser.
The R language server provides completion, hover (`K`), definitions (`gd`),
and diagnostics in scripts and R note chunks. Insert mode `<C-Space>` opens
completion; Tab moves through snippet placeholders.

PDF preview refreshes after a successful saved-file render. It does not rebuild
on each keystroke. The menu writes `notes.pdf` or `notes.html` beside the source,
including for existing `.Rmd` files. It forces PDF output through Tectonic;
project or custom output filenames are overridden for this menu's renders.

## Installed tools

- R: existing Homebrew installation.
- R packages: `languageserver`, `knitr`, `rmarkdown`, and R.nvim's `nvimcom`
  in the user library under `~/Library/R/arm64/4.6/library`.
- Quarto: official macOS package payload at `~/.local/share/quarto`, exposed
  as `~/.local/bin/quarto`. Neovim adds `~/.local/bin` to its PATH.
- PDF engine and viewer: existing Tectonic and Skim.

Use `:LspInfo` to check the R language server, `:RDebugInfo` for the R console,
and **Space v o** for render errors. Restart Neovim after installing this mode.

Configuration: `lua/plugins/r-notes.lua`, `lua/rnotes/init.lua`.
Note template: `templates/r-notes.qmd`.

References: https://github.com/R-nvim/R.nvim and https://quarto.org/docs/computations/r.html
