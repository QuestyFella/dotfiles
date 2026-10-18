# STM32 / MCU development in Neovim

This setup extends your existing LazyVim configuration. Space is the leader key.
C/C++ completion, diagnostics, references, rename, signature help and HAL navigation
come from clangd, using the project's real compile commands and Arm system headers.
Your existing FPGA configuration and other editor plugins remain available.

**New debug workspace:** restart Neovim, open an MCU project, then **Space m u**.
This previews the layout without connecting to hardware. Attach with **Space m d**
after starting your GDB server. **Space m v** opens the debug-view picker.

## First project

1. Generate your board project in STM32CubeMX using the **CMake** toolchain option.
   Keep the generated startup assembly, linker script, CMSIS and HAL drivers.
2. Open Neovim in the folder containing `CMakePresets.json`: `cd project && nvim .`.
3. Press **Space m c** to configure the default `Debug` preset. This creates
   `build/Debug/compile_commands.json` and restarts clangd with that database.
4. Press **Space m b** to build. Failed builds open the quickfix list; use `:cnext`
   and `:cprev` to jump through errors. `:copen` also shows successful build output.
5. Press **Space m z** to inspect ELF section sizes.
6. Use **Space m i** to create/edit `.nvim-mcu.json` when the project needs settings.

For another preset, **Space m p**, then configure and build again. Selection lasts
for this Neovim session; set `preset` in the JSON to persist it. The configure command
explicitly selects `build/<preset>`; set `build_dir` if your project requires a
different directory. An explicit `build_dir` is shared across preset selections.

Projects without presets use their own CMakeLists/toolchain configuration. For bare
metal builds, provide a CMake toolchain through a preset rather than allowing CMake
to select the host compiler. This editor does not invent CPU flags or linker scripts.

## Keys

| Key / command | Action |
|---|---|
| Space m c / `:MCUConfigure` | Configure CMake and refresh clangd |
| Space m b / `:MCUBuild` | Save files and build asynchronously |
| Space m p / `:MCUPreset` | Select a CMake configure preset |
| Space m z / `:MCUSize` | Inspect ELF sections with Arm size |
| Space m f / `:MCUFlash` | Select ELF, write/verify/reset using CubeProgrammer and SWD |
| Space m o / `:MCUServer` | Start OpenOCD in a terminal split |
| Space m d / `:MCUDebug` | Select ELF and attach GDB to the server |
| Space m s / `:MCUSerial` | Select a macOS serial port; default 115200 baud |
| Space m i / `:MCUInit` | Create/edit project settings without overwriting existing JSON |
| Space m k / `:MCUStop` | Cancel the running build/configure task |
| Space m h / `:MCUHelp` | Open this guide |
| Space m H / `:MCUHealth` | Check tools and compilation database |
| `gd` / `gr` / `K` | Definition / references / hover documentation |
| Space c r / Space c a | Rename / code actions |
| Space c h | Switch C/C++ source and header |
| Space c f | Format deliberately with clang-format |
| Space f f / Space s g | Find files / search project text |
| Space x x | Diagnostics list |

C/C++ format-on-save is disabled, including the first file opened at startup.
Formatting uses a project's `.clang-format`, otherwise LLVM style with two spaces
and an 80-column limit. clangd does not automatically insert headers on completion.
Preserve CubeMX `USER CODE` sections or keep application code in separate files so
regeneration does not overwrite it. An `.ioc` is editable as INI text; use CubeMX for
pin allocation, clock configuration and code generation.

## Per-project settings

For example, a **STM32F4** project using ST-LINK:

```json
{
  "preset": "Debug",
  "build_system": "cmake",
  "build_dir": "build/Debug",
  "elf": "build/Debug/my_firmware.elf",
  "openocd_interface": "interface/stlink.cfg",
  "openocd_target": "target/stm32f4x.cfg",
  "gdb_target": "localhost:3333",
  "baud": 115200
}
```

Use your actual ELF filename and MCU target. Omit `elf` to pick from built `.elf`
files; omit `build_dir` to follow preset selection automatically. `build_target`
optionally selects one CMake or Make target. No target family is assumed globally.
OpenOCD's installed target scripts are under `/opt/homebrew/share/openocd/scripts/target`.
For newer STM32 families, confirm support in the installed OpenOCD version or use
ST's GDB server instead; set `gdb_target` to its listening address.

Make projects can set `"build_system": "make"` and their actual `build_dir`/`elf`.
Builds run `make -jN` from the project root. Generate a compilation database using
Bear (`bear -- make ...`, requires a real compilation and a separately installed
Bear) or your build system's export facility. Put it in the root or `build_dir`.
Reopen the project after generating it, or run `:lsp restart clangd`.

## Flash and debug

1. Build **Debug** firmware with symbols. Connect the correct ST-LINK/SWD target.
2. **Space m f** selects the ELF and asks before writing and resetting the board.
   CubeProgrammer uses the ELF addresses and verifies the write. With multiple
   probes, use CubeProgrammer's CLI with an explicit probe serial number instead.
3. Set `openocd_target`, then **Space m o**. Wait for OpenOCD to report its GDB port.
4. Leave terminal input mode with **Esc Esc**, return to source, then
   **Space m d** or **F5** to attach. Attach does not flash or reset automatically.
   A single ELF is selected automatically; multiple ELFs show a picker.
5. In the debugger REPL (**Space d r**), use `monitor reset halt` for OpenOCD,
   set a breakpoint in `main`, then continue. Reset commands vary by server.

## Debug workspace

Attaching opens a separate debug tab. Your editing tab stays available; **Space m u**
closes the debug tab and returns to it, without disconnecting the debugger. Press it
again to reopen the workspace. Disconnect explicitly with **Space m q** / **Shift-F5**.
The last samples stay visible after disconnecting, labeled **DISCONNECTED**.

On a wide terminal (at least 160 columns and 40 rows):

```text
┌──────────────────┬─────────────────────────────────┬──────────────────────┐
│ Local variables  │ MCU STOPPED · stepping shortcuts│ CPU registers        │
│                  │                                 │ r0     0x00000001     │
├──────────────────┤ Source editor                   │ * r3   0x000000a4     │
│ Watch expressions│ current line + inline values    │ pc     0x08000022     │
├──────────────────┤                                 ├──────────────────────┤
│ Call stack       ├────────────────┬────────────────┤ Peripheral watches   │
├──────────────────┤ GDB console    │ Change history │ SPI2.CR1 = 0x034c    │
│ Breakpoints      │                │ r3: 1 -> 0xa4  │                      │
└──────────────────┴────────────────┴────────────────┴──────────────────────┘
```

The example values above illustrate the layout. Values come from GDB when attached.
Medium terminals show the source, right inspector and console/history. Small
terminals show source plus console/history. All views remain available as floating
windows through **Space m v**. Close and reopen the workspace after resizing to
choose a new layout. Use **Ctrl-h/j/k/l** to move between panes and **q** / **Esc**
to close a floating inspector. The source toolbar and statusline show debugger state.

| Key / command | Debug action |
|---|---|
| F9 / Space d b | Toggle breakpoint |
| Space d B | Conditional breakpoint |
| F5 | Attach if disconnected; continue if attached |
| F6 / Space d P | Pause |
| F7 | Step one machine instruction |
| F8 / Space d C | Run to cursor |
| F10 / Space d O | Step over |
| F11 / Space d i | Step into |
| F12 / Shift-F11 / Space d o | Step out |
| Shift-F5 / Space m q / `:MCUDisconnect` | Disconnect GDB without requesting program termination |
| Space m u / Space d u / `:MCUWorkbench` | Open/close the debug workspace |
| Space m v / `:MCUViews` | Choose any debug view |
| Space m r / `:MCURegisters` | CPU registers |
| Space m P / `:MCUPeripherals` | Peripheral watch inspector |
| Space m M / `:MCUMemory [expression]` | Inspect 32 bytes at an address/pointer |
| Space m a / `:MCUDisassembly` | Disassemble 24 instructions from the halted PC |
| Space m t / `:MCUTrace` | CPU/peripheral change history |
| Space m w / `:MCUWatch` | Add a variable/watch expression |
| Space m W / `:MCUWatchpoint` | Break on writes, reads or accesses to an expression |
| Space m l / `:MCULogpoint` | Set a source logpoint, with `{expression}` interpolation |
| Space m R / `:MCURefresh` | Refresh the halted target |
| Space d e | Evaluate expression under cursor / selection |
| Space d r | GDB command REPL |

macOS may require **Fn** with function keys. Existing LazyVim **Space d** commands
remain available. In scopes/watches, **Enter** expands structures, **e** edits and
**d** removes a watch. Pointer/struct values use the ELF's debug information.

### CPU register tracing

Registers are read from the innermost frame of the stopped thread. **\*** and amber
highlighting mark changes from the previous sample. Each debugger stop records the
reason, function/line and old/new values in the history. It retains the newest 400
lines. **r** refreshes a pane; **C** clears history; **s** in history (or
`:MCUTraceExport`) saves it to a new text file. Manual refresh updates the baseline
without adding a new stop to history.

This is **halted-state tracing**, refreshed at breakpoints, pauses and steps. While
running, panes explicitly show that their values are from the last halt. It is not
continuous SWO/ITM/ETM capture. Memory/disassembly are read only while their inspector
is visible. Restarting an attach session clears the old register baseline/history.

### Peripheral registers

Open **Space m P**, then **a** to watch an expression; **dd** removes its row. For
example, `:MCUPeripheral *(unsigned int *)0x40003800` reads one 32-bit register.
That address is the SPI2 CR1 example for an STM32F411; use the address and access width
from **your actual MCU's** reference manual. A CMSIS expression such as `SPI2->CR1`
also works if GDB has its macro/type information (often requires `-g3`).

Only explicitly selected registers are read. Reads occur at every stop and on manual
refresh; avoid FIFO/data and read-to-clear registers whose reads change device state.
GDB's hover evaluation disables assignments and function calls, but memory reads can
still have peripheral side effects. No register is automatically written.

Per-project watches are saved under `~/.local/share/nvim/mcu/`. To seed a project's
list, add this optional field to `.nvim-mcu.json` before its first saved list:

```json
"peripheral_watches": [
  { "name": "SPI2.CR1", "expression": "*(unsigned int *)0x40003800" }
]
```

Saved lists take precedence over the seed; up to 32 entries are supported. Peripheral
changes also appear in history. This is an expression/address inspector, without an
SVD register tree or bitfield decoding. Automatic RTOS task discovery is not configured.

### Memory and watchpoints

**Space m M** accepts `$sp`, a literal address, a pointer variable or `&buffer`.
It shows 32 bytes in hex; **a** changes the address. **Space m a** shows instruction
bytes and assembly at the CPU's halted PC; **F7** steps one instruction.

**Space m W** asks for an expression (for example, `counter` or
`*(unsigned int *)0x20000000`) and write/read/access mode. GDB reports whether a
hardware watchpoint was installed; available slots and supported widths depend on
the core/probe. Watchpoints created through GDB are managed in the REPL with
`info breakpoints` and `delete NUMBER`; they are not listed in DAP's source-breakpoint
pane. Do not assume arbitrary peripheral addresses support hardware watchpoints.

REPL commands include `info registers`, `p/x variable`, `x/16wx 0x20000000`, and
`disassemble /m main`. Disconnect GDB before stopping OpenOCD with Ctrl-C in its terminal.

The adapter uses the installed Python-enabled `arm-none-eabi-gdb-py`, since the
plain Arm GDB binary lacks Python/DAP support. It can attach to an already-running
OpenOCD, J-Link or ST GDB server. Other architectures need their own DAP-capable GDB
and adapter configuration in `lua/plugins/mcu.lua`; RISC-V compiler querying is
allowed for clangd, but this does not install a RISC-V SDK or debugger.

## Serial

**Space m s** opens picocom after selecting `/dev/cu.*`. Set `baud` to match the
firmware. Exit picocom with **Ctrl-A Ctrl-X**. A connected USB virtual COM port is
needed; SWD alone does not carry UART data. Terminal normal mode: **Ctrl-\\ Ctrl-n**.
**Esc Esc** also leaves terminal input; **Ctrl-h/j/k/l** switches panes. Serial and
OpenOCD terminals are reused per project, so invoking them again focuses the running
session instead of launching another process on the same port. Closing their split
hides it; stop picocom/OpenOCD explicitly when finished.

## Maintenance and troubleshooting

- `:MCUHealth` checks tool resolution and the active compilation database.
- Missing HAL/CMSIS headers: configure the correct preset and inspect `:checkhealth vim.lsp`.
- Wrong standard headers: use the complete Arm GNU toolchain, not a compiler-only
  installation. Neovim prepends the installed Arm toolchain and Homebrew LLVM to
  its own PATH; your shell configuration is unchanged.
- CubeProgrammer device database: the flash command resolves the CLI symlink and
  runs from its installation bin directory so its device database can be found.
- Stale CMake compiler paths: select a fresh build directory in `.nvim-mcu.json`
  and configure again. Existing build caches retain their compiler selection.
- A project `.clangd` that specifies `CompilationDatabase` takes precedence over
  the initialization setting; align it with your selected build directory.
- `:Lazy` manages plugins; `:TSUpdate` updates syntax parsers; `:Mason` manages
  other language tools. clangd and clang-format here come from Homebrew LLVM.
- Before this UI customization: `~/.config/nvim-backups/before-debug-ui-20260919/`.
  Original pre-MCU backup: `~/.config/nvim-backups/before-mcu-20260916/`.
  To restore, close Neovim, move the current config aside and copy that backup to
  `~/.config/nvim`. Installed OpenOCD/picocom and plugin data are separate.

## Validation performed

On 2026-09-19: verified the new workspace through the installed Arm GDB DAP adapter
against a QEMU Cortex-M4 with a temporary test ELF. Passed attach, source breakpoint,
source/instruction stepping, CPU and peripheral-value change history, memory reads,
disassembly, GDB hardware-watchpoint creation, rejection of delayed stale responses,
disconnect/sample retention, and full/medium/small workspace layouts. No physical
board was flashed, reset or connected during these checks.

The reproducible check creates its own temporary firmware and emulator:

```sh
nvim --headless '+lua dofile(vim.fn.stdpath("config") .. "/tests/mcu_debug.lua")'
```

Requires the installed Arm GNU toolchain and `qemu-system-arm`, plus permission to
bind/connect a localhost GDB port. `MCU_TEST_PORT` can override the default 54334.

On 2026-09-16: configured and built a temporary copy of LIS2MDL_BETA_DRIVER for
STM32F411; produced an ELF with 14,032 text bytes, 92 data bytes and 2,060 BSS bytes.
clangd checked main.c with zero errors, and Neovim resolved HAL_Init into the HAL
source. The Arm GDB DAP initialization handshake passed. No board was flashed,
reset or debugged, and serial traffic was not hardware-tested.

References: [clangd compile commands](https://clangd.llvm.org/design/compile-commands),
[LazyVim C/C++ extra](https://www.lazyvim.org/extras/lang/clangd),
[GDB DAP](https://www.sourceware.org/gdb/current/onlinedocs/gdb.html/Debugger-Adapter-Protocol.html).

Follow-up: confirmed hot-plug identification of the connected NUCLEO-F411RE
(STM32F411xC/E, device ID 0x431, 512 KB flash) after fixing CubeProgrammer
working-directory resolution. This check did not flash or reset the target.
