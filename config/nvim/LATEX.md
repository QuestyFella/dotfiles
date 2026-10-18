# LaTeX notes

Open a `.tex` file to enter LaTeX mode, or run `:LatexNote` / Space j n
for a new lecture-note template. Save it with `:w ~/Documents/notes.tex`.
The first build downloads TeX packages and needs an internet connection;
later builds reuse Tectonic's cache.

Saving builds the PDF with Tectonic. VimTeX opens it in Skim after a successful
build; Skim can refresh as the PDF changes. Keep Skim beside Neovim for preview.
If Skim asks whether to reload changed files, enable automatic reloading.
Space j v opens the PDF at the source cursor using SyncTeX.

## Space j menu

| Keys | Action |
| --- | --- |
| Space j n | New note template |
| Space j b | Save and build |
| Space j B | Rebuild even without edits |
| Space j v | PDF preview / forward search |
| Space j a | Toggle building on save for this buffer |
| Space j e | Build errors |
| Space j o | Compiler output |
| Space j t | Section outline |
| Space j i | Project information |
| Space j s | Spelling suggestions for word |
| Space j c | Apply first spelling suggestion (`u` to undo) |
| Space j w | Add word to personal dictionary |
| Space j m | Insert display equation snippet |
| Space j f | Insert fraction snippet |
| Space j h | This guide |

Texlab supplies command completion, labels/references, citations, navigation,
and diagnostics through the existing LSP/completion UI. `K` opens hover help;
`gd` goes to a definition. Existing LaTeX snippets appear in completion.
Use Tab / Shift-Tab to move through snippet placeholders.

Spelling is enabled for prose; VimTeX syntax excludes many commands and math
regions. Use `]s` / `[s` to jump between spelling issues. Correction is explicit:
Space j c replaces the current word with the first suggestion. This avoids
silently rewriting technical vocabulary or equations. Soft wrapping is enabled
in TeX windows; `gj` / `gk` move by visual line.

For multi-file notes, add `% !TeX root = main.tex` to chapter files so VimTeX
builds the main document. Tectonic is a XeTeX-based compiler; projects requiring
LuaLaTeX or unusual external tools may need a full TeX distribution instead.
Formatting via latexindent is not installed by this setup.

## Troubleshooting

- `:checkhealth vimtex` checks the compiler/viewer setup.
- `:LspInfo` shows whether Texlab attached.
- `:VimtexErrors` and `:VimtexCompileOutput` show failed builds.
- Dependencies: `brew install tectonic texlab` and `brew install --cask skim`.
- VimTeX's original comma-prefixed mappings remain available (` ,ll`, `,lv`).
- Compiler/viewer options: `lua/plugins/latex.lua`; notes menu: `lua/latex/init.lua`.

Reference: https://github.com/lervag/vimtex
