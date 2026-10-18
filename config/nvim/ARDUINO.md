# Arduino / ESP32 mode

Restart Neovim, open `Sketch/Sketch.ino`, and press **Space a**.
Arduino mode also recognizes `.c`, `.cpp`, and `.h` files inside a sketch.
Use `:ArduinoNew` (**Space a n**) to create a sketch with a 115200-baud serial example.

## Daily workflow

1. **Space a b**: choose your exact board. Uno, Nano, Nano old bootloader, and
   ESP32 Dev Module appear first; the searchable list includes all installed variants.
2. **Space a o**: choose processor/bootloader, ESP32 flash size, partition scheme,
   upload speed, or other options provided by that board's core.
3. **Space a c**: save this sketch's buffers and compile. No connected board is needed.
4. **Space a p**: select the connected board's serial port.
5. **Space a u**: save, compile, then upload and verify. A failed compile prevents upload.
6. **Space a s**: open the timestamped serial monitor. Default baud is 115200;
   **Space a r** changes it to match `Serial.begin(...)` in your code.

The selected board, options, port, and baud are stored beside the sketch in
`.nvim-arduino.json`. Each sketch has its own settings and separate build cache.
The mode does not infer a board model from an unknown USB-to-serial adapter.

**Uno** here means the classic ATmega328P Uno/R3. **Nano** means the classic AVR
Nano. Uno R4 and newer Nano families need their own cores and board selections.
For an ESP32-C3/S3/etc., choose that exact board instead of the classic ESP32 entry.
Nano clones may need **ATmega328P (Old Bootloader)**; change this through the
board picker or the Processor option.

## UI and keys

| Keys | Action | Command |
|---|---|---|
| Space a a | Action picker | `Arduino` |
| Space a w | Code, sketch panel, and build output | `ArduinoWorkbench` |
| Space a b | Board picker | `ArduinoBoard` |
| Space a o | Board options / bootloader | `ArduinoOptions` |
| Space a p | Port picker | `ArduinoPort` |
| Space a c | Compile | `ArduinoBuild` |
| Space a u | Compile + upload + verify | `ArduinoUpload` |
| Space a s | Open/focus serial monitor | `ArduinoSerial` |
| Space a S | Stop serial monitor and release port | `ArduinoSerialClose` |
| Space a r | Serial baud rate | `ArduinoBaud` |
| Space a e | Full build output | `ArduinoOutput` |
| Space a k | Cancel the current task | `ArduinoStop` |
| Space a l | Search and install a library | `ArduinoLibrary` |
| Space a n | New sketch | `ArduinoNew` |
| Space a i | Edit this sketch's settings | `ArduinoSettings` |
| Space a R | Restart this sketch's language server | `ArduinoRestart` |
| Space a h | This guide | `ArduinoHelp` |
| Space a H | Tool/core checks | `ArduinoHealth` |

The statusline shows the board, selected port, and running task. The workspace's
right pane shows settings and shortcuts; the bottom pane streams compiler output.
Press `q` in either information pane to close it. Compiler errors populate quickfix:
`:copen` shows them, and Enter jumps to the source line.

In serial, **Esc Esc** returns to normal mode; **Ctrl-h/j/k/l** changes panes.
An upload stops this mode's monitor before taking the port. Reopen it afterward.
If Arduino IDE, `screen`, or another application owns the port, close its monitor too.

## Editing

Arduino Language Server supplies board-aware completion, diagnostics, hover (`K`),
definition (`gd`), references (`gr`), and rename (**Space c r**) through LazyVim.
Choose a board first; the first indexing pass can take a while, especially on ESP32.
Changing the board/options restarts the language server for that sketch.
`.ino` uses the C++ syntax parser and two-space indentation. Formatting is manual
with **Space c f**. Companion C/C++ files use the Arduino server instead of the
standalone STM32 clangd configuration.

The Arduino commands use the normal Arduino CLI configuration at
`~/Library/Arduino15/arduino-cli.yaml`, with Espressif's stable package index added.
Installed libraries use the CLI's sketchbook library directory. Run
`:ArduinoUpdateIndex` to refresh board and library listings. Core upgrades are
explicit CLI operations (`arduino-cli core upgrade`), not automatic on editor startup.

This mode uses `.nvim-arduino.json` for its board/port selection, not `sketch.yaml`
build profiles. Build artifacts live in Neovim's cache, outside your source tree.

## Hardware and debugging

Compiling, completion, code navigation, and editing work without a board. Compilation
does not execute the sketch or validate timing, GPIO, Wi-Fi, sensors, or wiring.
Uploading and serial monitoring need a connected board.

The existing STM32 **Space m** workflow and debug function keys remain available.
Arduino mode adds build/upload/serial tooling; it does not configure AVR or ESP32
breakpoint debugging, register views, a serial plotter, or simulation. Those require
board-specific debugger/simulator support beyond this mode.

## Installation and recovery

Arduino CLI is installed with Homebrew; Arduino Language Server 0.7.7 is installed
from its verified official ARM64 release in `~/.local/bin/arduino-language-server`.
The existing AVR core 1.8.8 was reused. ESP32 uses the official **3.1.3** core:
the latest 3.3.12 package exhausted the available disk space while unpacking, so
its partial files were removed and this smaller release was installed. Upgrading
later requires additional free space.

ESP32 sketches use Espressif clangd **22.1.4 (20260825)** in
`~/.local/share/arduino-tools/esp-clangd`, with matching LLVM 22.1.4 builtin headers.
This avoids the generic LLVM backend's false Xtensa errors. Uno/Nano and STM32
continue using the existing LLVM installation.

The pre-change Neovim config is saved at
`~/.config/nvim-backups/before-arduino-20260921`.

## Validation (2026-09-21)

- Real firmware builds: Uno, Nano ATmega328P, Nano old bootloader, and ESP32 Dev Module.
- Real language-server checks: Arduino hover, Serial.begin completion, no errors
  on valid sketches, and companion C++ attachment without duplicate clangd clients.
- An intentional compiler error navigated back to the correct `.ino` line.
- Board selection stayed with its original sketch when changing editor buffers.
- Workspace panes reused their windows; a mock serial process stopped before the
  captured compile/upload command and reopened in the same window.
- Tool/core health passed. Existing STM32 root detection and shortcuts passed.
- Physical flashing and serial communication remain untested: no board was connected.

Repeat the hardware-free editor checks:

```sh
nvim --headless '+lua dofile(vim.fn.stdpath("config") .. "/tests/arduino.lua")'
ARDUINO_TEST_FQBN=esp32:esp32:esp32 nvim --headless '+lua dofile(vim.fn.stdpath("config") .. "/tests/arduino.lua")'
nvim --headless '+lua dofile(vim.fn.stdpath("config") .. "/tests/arduino_serial.lua")'
```

References: [Arduino CLI](https://docs.arduino.cc/arduino-cli/getting-started),
[Arduino Language Server](https://github.com/arduino/arduino-language-server),
[Espressif Arduino installation](https://docs.espressif.com/projects/arduino-esp32/en/latest/installing.html).
