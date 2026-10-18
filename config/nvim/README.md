# Neovim

LazyVim with STM32/MCU, Arduino/ESP32, FPGA development, and LaTeX/R notetaking.

R: open `.R`, `.Rmd`, or `.qmd`, or run `:RNote`. **Space v** opens the R menu.
**Space v r** starts the console; **Space v l** runs a line or selection.
Save notes to render and preview their PDF in Skim; **Space v a** toggles this.
Guide: [R-NOTES.md](R-NOTES.md) or `:RNotesHelp`.

LaTeX: open a `.tex` file or use `:LatexNote`. **Space j** opens the notes menu.
Save to build and preview the PDF in Skim. **Space j s** shows spelling suggestions;
**Space j c** applies the first correction. Guide: [LATEX.md](LATEX.md) or `:LatexHelp`.

Arduino: open a sketch's `.ino` file and press **Space a** for its menu.
**Space a b** selects a board; **Space a c** compiles; **Space a u** builds and uploads.
**Space a w** opens the sketch workspace. Guide: [ARDUINO.md](ARDUINO.md) or `:ArduinoHelp`.

Open [MCU.md](MCU.md) for setup, shortcuts, build/flash/debug instructions and validation.
Inside Neovim: `:MCUHelp` or **Space m h**. Tool checks: `:MCUHealth`.

**Space m u** previews the STM32 debug workspace; **Space m v** selects a view.
Includes CPU/peripheral register changes, history, watches, memory, disassembly,
breakpoints, GDB and reusable serial/OpenOCD terminals. **F5** attaches/continues.
