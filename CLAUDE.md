# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this is

An FPGA project, not a typical software repo: a **Nios V/g** (RISC-V) softcore on a **Terasic MAX 10 Plus** board (`10M50DAF484C6GES`), with a Verilog block invoked as a **custom instruction** from C. It is the PoC foundation for PhD research on hardware acceleration of lattice-based PQC (Kyber/Dilithium). See `README.md` and the full build walkthrough in `SETUP.md`.

There is **no automated test suite, linter, or one-command build.** Building is part GUI (Quartus Prime 25.1), part CLI (Nios V Command Shell). Toolchain installed at `C:\altera\25.1std`; the Nios V shell is `C:\altera\25.1std\niosv\bin\niosv-shell.exe` (a bash-style shell — use forward-slash paths).

## Build & run

Hardware (Quartus GUI): Platform Designer **Generate HDL** (if `niosv_system.qsys` changed) → **Processing → Start Compilation** (→ `output_files/top.sof`) → **Tools → Programmer → Start**.

Software (in the Nios V Command Shell, from the project root):
```bash
niosv-bsp --create --type=hal --sopcinfo=niosv_system.sopcinfo software/bsp/settings.bsp
cmake -S software/app -B software/app/build -G "Unix Makefiles"
cmake --build software/app/build
niosv-download -g software/app/build/hello.elf   # load to RAM + run
juart-terminal                                    # view stdout over JTAG
```

## Rebuild rules (important — they decide which steps to rerun)

- **Edited only HDL *logic* (e.g. `custom_adder.v` internals):** recompile + reprogram `.sof` + re-`niosv-download`. **No BSP/app rebuild.**
- **Changed the hardware *interface*/system** (new/changed custom instruction, peripheral, memory map): Generate HDL → recompile → reprogram → **regenerate the BSP** (so `system.h` updates) → rebuild app.
- **Edited only C:** rebuild app + re-`niosv-download` (no Quartus recompile).

## Architecture: how the custom instruction is wired end-to-end

Understanding this requires `niosv_system.qsys`, `top.v`, `custom_adder.v`, and the generated `software/bsp/system.h` together:

1. In the **Nios V/g IP "Custom Instructions" tab** (inside `niosv_system.qsys`) two tables define the instruction: the *Hardware Interfaces Table* (`opcode` + `funct7[6:4]`) creates a hardware conduit; the *Software C-Macro Table* generates the C macro. They are linked by matching `funct7[6:4]`. The current instruction: `CUSTOM0`, all funct bits `0`, mnemonic `ADD32`.
2. Generating HDL exposes an auto-exported **`add32_ci_*` conduit** on the `niosv_system` module (signals: `clk, reset, data0, data1, ctrl, alu_result, enable` out; `result, done` in).
3. **`top.v`** instantiates `niosv_system` and wires that conduit to **`custom_adder.v`**.
4. The BSP generates **`ADD32(a,b)` in `system.h`** — a macro emitting `.insn r 0x0B, ...` (opcode CUSTOM0) that returns the result. `hello.c` includes `system.h` and calls it.

To add more accelerated operations, add rows to the two tables (distinct `funct` bits, selected in hardware via the `ctrl` input), regenerate, and follow the interface-change rebuild rule.

## Non-obvious constraints (violating these breaks the build or silently hangs the CPU)

- **Custom instructions require the Nios V/g core** — V/m and V/c have no Custom Instructions tab.
- The custom-instruction conduit is a **variable-latency `enable`/`done` handshake**. A combinational `done = enable` **hangs the CPU** (it samples `done` the cycle after `enable`). Register it: on the rising edge of `enable`, latch the result and pulse `done` for one cycle (see `custom_adder.v`).
- **MAX 10 needs config mode "…with Memory Initialization"** (`INTERNAL_FLASH_UPDATE_MODE "SINGLE IMAGE WITH ERAM"` in `top.qsf`), or the Assembler fails with `Error (14703)`.
- **Nios V/g needs a non-cacheable Peripheral Region** covering all memory-mapped peripherals, or `printf`/JTAG UART silently fails. Currently base `0x00030000`, size 64 KB (set in the `cpu` IP).
- Board pins (from the manual): clock `PIN_N5` (2.5 V), reset_n = KEY0 `PIN_T22` (1.5 V), active-low.
- `altera_reserved_tck` clock-uncertainty critical warnings are harmless (no `.sdc` yet).

## Editing the .qsf

`top.qsf` is co-managed by Quartus. When editing it while Quartus has the project open, the edits may need a project reload to take effect (and Quartus may rewrite the file). Prefer the GUI for assignments when the project is open, or reload after external edits.

## Source vs generated

Tracked sources: `*.qpf *.qsf *.qsys *.v *.c` + `software/app/CMakeLists.txt`. Everything else (`db/`, `output_files/`, `niosv_system/`, `simulation/`, `*.sopcinfo`, `software/bsp/`, `software/app/build/`) is generated and git-ignored — regenerate per `SETUP.md`. Note `software/app/CMakeLists.txt` references `../bsp`, so the BSP must be regenerated before the first app build.
