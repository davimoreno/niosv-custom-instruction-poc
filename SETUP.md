# Nios V/g + Custom Instruction PoC — Setup Guide

Reproduces a Nios V/g softcore on the **Terasic MAX 10 Plus** (`10M50DAF484C6GES`) with a Verilog 32-bit adder invoked as a **custom instruction** from C.

---

## 1. Install software

Install **Quartus Prime 25.1** (Lite is free and sufficient; Standard also works). During install select:

- **Device support: MAX 10 only** (skip all other families).
- **Nios V** tools (RISC-V GCC + `niosv-*` tools — included in core install).
- **Ashling RiscFree IDE for Altera** (Nios V debugger; optional if using the CLI).
- Add-ons: **Quartus Prime Driver Installer**; post-install, install the **USB-Blaster + USB-Blaster II** drivers.

Install path must have **no spaces** (default `C:\altera\25.1std` is fine).

> If the web installer fails with `SSL certificate problem (Curlcode 60)`, download the **offline/standalone installer** via a browser and install from disk (common on TLS-inspecting networks).

---

## 2. Create the Quartus project

1. **New Project Wizard** → top-level entity `top`.
2. Device family **MAX 10**, device **`10M50DAF484C6GES`**.

---

## 3. Build the Nios V/g system (Platform Designer)

**Tools → Platform Designer**, save as `niosv_system.qsys`. Add and connect:

| Component | Notes |
|---|---|
| Clock Source (`clk_0`) | 50 MHz |
| **Nios V/g** Processor (`cpu`) | **must be V/g** — only V/g supports custom instructions |
| On-Chip Memory RAM (`onchip_ram`) | 128 KB |
| JTAG UART (`jtag_uart`) | stdout |
| System ID (`sysid`), Interval Timer (`timer`) | optional/useful |

**Connections:** `clk_0.clk`→ all clk inputs; `clk_0.clk_reset`→ all reset inputs; `cpu.instruction_manager`→ `onchip_ram`; `cpu.data_manager`→ `onchip_ram` + `jtag_uart` + `sysid` + `timer`; connect `jtag_uart` and `timer` IRQs to `cpu`.

**cpu settings (critical):**
- **Reset Agent = `onchip_ram`** (this is the reset vector; no separate exception-vector setting on RISC-V).
- **Peripheral Region A**: Base `0x00030000`, Size `64 KB`. *(Required on V/g — peripherals must be non-cacheable or `printf` silently fails. Verify it covers all peripherals via the Address Map; adjust base/size if your map differs.)*

**Custom Instruction tab — add one row to each table:**

*Hardware Interfaces Table:*

| opcode | funct7[6:4] |
|---|---|
| `CUSTOM0` | `000` |

*Software C-Macro Table:*

| opcode | funct7[6:4] | funct7[3:0] | funct3[2:0] | Mnemonic |
|---|---|---|---|---|
| `CUSTOM0` | `000` | `0000` | `000` | `ADD32` |

Then **System → Assign Base Addresses**, confirm 0 errors, and **Generate HDL** (Verilog). The CPU now exposes an auto-exported `add32_ci_*` conduit.

---

## 4. Top-level + custom instruction logic

**`custom_adder.v`** — single-cycle adder using the variable-latency `enable`/`done` handshake (a combinational `done = enable` HANGS the CPU; it must be registered):

```verilog
module custom_adder (
    input  wire        clk, reset,
    input  wire [31:0] data0, data1, ctrl, alu_result,
    input  wire        enable,
    output reg  [31:0] result,
    output reg         done
);
    reg enable_d;
    always @(posedge clk or posedge reset) begin
        if (reset) begin enable_d<=0; done<=0; result<=0; end
        else begin
            enable_d <= enable;
            if (enable & ~enable_d) begin result <= data0 + data1; done <= 1'b1; end
            else                          done <= 1'b0;
        end
    end
endmodule
```

**`top.v`** — wraps the system and wires the conduit to the adder:

```verilog
module top (input wire clk, input wire reset_n);
    wire ci_clk, ci_reset, ci_enable, ci_done;
    wire [31:0] ci_data0, ci_data1, ci_ctrl, ci_alu_result, ci_result;

    niosv_system u0 (
        .clk_clk(clk), .reset_reset_n(reset_n),
        .add32_ci_clk(ci_clk), .add32_ci_reset(ci_reset),
        .add32_ci_data0(ci_data0), .add32_ci_data1(ci_data1),
        .add32_ci_ctrl(ci_ctrl), .add32_ci_alu_result(ci_alu_result),
        .add32_ci_enable(ci_enable), .add32_ci_result(ci_result),
        .add32_ci_done(ci_done)
    );
    custom_adder u_adder (
        .clk(ci_clk), .reset(ci_reset), .data0(ci_data0), .data1(ci_data1),
        .ctrl(ci_ctrl), .alu_result(ci_alu_result), .enable(ci_enable),
        .result(ci_result), .done(ci_done)
    );
endmodule
```

---

## 5. Quartus assignments (`top.qsf`)

```tcl
set_global_assignment -name QIP_FILE niosv_system/synthesis/niosv_system.qip
set_global_assignment -name VERILOG_FILE top.v
set_global_assignment -name VERILOG_FILE custom_adder.v

# Pins (Terasic MAX 10 Plus): 50 MHz clock = N5 (2.5V), KEY0 reset = T22 (1.5V)
set_location_assignment PIN_N5 -to clk
set_instance_assignment -name IO_STANDARD "2.5 V" -to clk
set_location_assignment PIN_T22 -to reset_n
set_instance_assignment -name IO_STANDARD "1.5 V" -to reset_n

# Required for MAX 10 designs with initialized on-chip memory
set_global_assignment -name INTERNAL_FLASH_UPDATE_MODE "SINGLE IMAGE WITH ERAM"
```

> The last line is set via **Device → Device and Pin Options → Configuration → "Single Uncompressed Image with Memory Initialization"**. Without it the Assembler fails: `Error (14703): Invalid internal configuration mode for design with memory initialization`.

---

## 6. Compile & program

1. **Processing → Start Compilation** → produces `output_files/top.sof`.
   *(`altera_reserved_tck` clock-uncertainty critical warnings are harmless.)*
2. **Tools → Programmer** → Hardware Setup → USB-Blaster → Auto Detect → add `top.sof` → **Start**.

---

## 7. Build & run software (Nios V Command Shell)

Open **Nios V Command Shell** (`C:\altera\25.1std\niosv\bin\niosv-shell.exe`), `cd` to the project, then:

```bash
# BSP (regenerate whenever the hardware/.sopcinfo changes)
niosv-bsp --create --type=hal --sopcinfo=niosv_system.sopcinfo software/bsp/settings.bsp

# App (generates CMakeLists; ADD32 macro lands in software/bsp/system.h)
niosv-app --bsp-dir=software/bsp --app-dir=software/app --srcs=software/app/hello.c --elf-name=hello.elf

# Build
cmake -S software/app -B software/app/build -G "Unix Makefiles"
cmake --build software/app/build

# Download to RAM, run, view output
niosv-download -g software/app/build/hello.elf
juart-terminal
```

**`software/app/hello.c`** — call the BSP-generated macro:

```c
#include <stdio.h>
#include <stdint.h>
#include "system.h"      /* defines ADD32(a,b) -> hardware custom instruction */

int main(void) {
    uint32_t a = 123456, b = 654321;
    uint32_t hw = (uint32_t) ADD32(a, b);
    printf("ADD32(%lu,%lu) = %lu  (sw=%lu)\n",
           (unsigned long)a, (unsigned long)b, (unsigned long)hw, (unsigned long)(a+b));
    while (1) {}
}
```

`ADD32(a, b)` expands to `.insn r 0x0B, 0x0, 0x0, ...` (opcode CUSTOM0) and returns the hardware result.

---

## Gotchas (summary)

| Symptom | Fix |
|---|---|
| Custom instruction tab missing | Use **Nios V/g** (not V/m or V/c) |
| `printf` silently fails on V/g | Define a **Peripheral Region** covering all peripherals |
| Assembler `Error (14703)` | Config mode **"…with Memory Initialization"** |
| Program restarts, never reaches code after a custom-instruction call | Register the `enable`/`done` handshake (don't use combinational `done = enable`) |
| Installer SSL `Curlcode 60` | Use the **offline installer** |

## Rebuild rules

- Hardware logic change only (e.g. `custom_adder.v`): recompile + reprogram `.sof` + re-`niosv-download`. **No BSP/app rebuild.**
- Hardware *interface*/system change (new custom instruction, new peripheral): regenerate HDL → recompile → reprogram → **regenerate BSP** → rebuild app.
```
