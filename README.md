# Nios V/g Custom-Instruction PoC (MAX 10 Plus)

A proof-of-concept that runs a **Nios V/g** RISC-V softcore on a **Terasic MAX 10 Plus** FPGA board and accelerates a computation in hardware via a **custom instruction** — a Verilog block invoked directly from C.

This is the foundation for a PhD research effort on **hardware acceleration of lattice-based post-quantum cryptography (PQC)** (e.g. Kyber/ML-KEM, Dilithium/ML-DSA). The adder here is a deliberately minimal example that exercises the full custom-instruction flow; the same flow scales to PQC kernels such as modular reduction and NTT butterflies.

## What it does

A 32-bit adder (`custom_adder.v`) is attached to the Nios V/g custom-instruction interface. C code calls the BSP-generated macro `ADD32(a, b)`, which issues a single RISC-V custom-opcode instruction (`CUSTOM0`) and returns the hardware result — verified against a software reference.

```
C:  uint32_t r = ADD32(a, b);
        │  (.insn r 0x0B, ... — opcode CUSTOM0)
        ▼
HW: result = data0 + data1   (custom_adder.v on the add32_ci conduit)
```

## Target

| | |
|---|---|
| Board | Terasic MAX 10 Plus |
| FPGA | `10M50DAF484C6GES` (MAX 10, 50K LE, 144 DSP) |
| Softcore | Nios V/g (only the V/g variant supports custom instructions) |
| Tools | Quartus Prime 25.1 + Nios V tools (RISC-V GCC, `niosv-*`) |
| Clock / Reset | 50 MHz (`PIN_N5`) / KEY0 active-low (`PIN_T22`) |

## Repository layout

| Path | Description |
|---|---|
| `template-nios-project.qpf` | Quartus project |
| `top.qsf` | Assignments: source files, pins, MAX 10 config mode |
| `niosv_system.qsys` | Platform Designer system (CPU, RAM, JTAG UART, timer, sysid, custom-instr interface) |
| `top.v` | Top level: wraps the system, wires the `add32_ci` conduit to the adder |
| `custom_adder.v` | The 32-bit adder, implementing the variable-latency `enable`/`done` handshake |
| `software/app/hello.c` | Test program calling `ADD32()` |
| `SETUP.md` | **Full step-by-step build/replication guide** |
| `MAX_10_Plus_User_manual.pdf` | Board reference (pinout, clocks) |

Generated artifacts (`db/`, `output_files/`, `niosv_system/`, `software/bsp/`, build output) are git-ignored and rebuilt from the sources above.

## Quick start

See **[SETUP.md](SETUP.md)** for the complete walkthrough. In short, from a checkout:

1. Open the project in Quartus → Platform Designer → **Generate HDL** (regenerates `niosv_system/`).
2. **Compile** → program `output_files/top.sof` to the board.
3. In the **Nios V Command Shell**:
   ```bash
   niosv-bsp --create --type=hal --sopcinfo=niosv_system.sopcinfo software/bsp/settings.bsp
   cmake -S software/app -B software/app/build -G "Unix Makefiles"
   cmake --build software/app/build
   niosv-download -g software/app/build/hello.elf
   juart-terminal
   ```

Expected output: each `ADD32(a, b)` matches the software sum, ending in `ALL TESTS PASSED`.

## Next steps (research)

- Replace the adder with a **modular** add/sub (`q = 3329` Kyber, `q = 8380417` Dilithium), then Montgomery/Barrett multiply — multiple ops selected via the custom-instruction `funct` bits.
- **Profile** reference C kernels (NTT, Keccak/SHAKE) to decide which belong as custom instructions vs **memory-mapped Avalon accelerators** (for bulk/streaming work).
- Add a `top.sdc` for proper timing constraints as the design grows.
