# 0005 — Physical memory configuration (silicon vs simulation)
Status: proposed (C, Wk7); needs A ack (interacts with 0006).

Silicon Config S: IMEM/DMEM = sky130_sram_2kbyte_1rw1r_32x512_8 (512x32) each; addr[13:11] aliased; DMEM organised as 1024x8 bytes via wmask0; clk0/clk1 tied to core clk; vccd1/vssd1 via PDN (omitted from verilog blackbox).

Sim unchanged: imem 4096x32 combinational; dmem 1024x8 with combinational port B.

Rationale: only 1/2 KB configs ship LEF+LIB+GDS in efabless/sky130_sram_macros; 16 KB banking is area-feasible (~6.8 mm² die) but Week-7-risky; workload fits (256-word program + 39-word weights << 512 words).

Macro footprint measured: 683.10 x 416.54 µm = 284,538 µm² each.

Die budget: logic 211,318.92 + 2x284,538 = 780,394.92 µm² hard; core 1650x1650 @ ~29%; die 1850x1850 (~3.4 mm²).

riscv-tests remain simulation-only.

Correction log: an earlier "16 KB silicon infeasible" claim was wrong (misrecalled macro size); Config S is chosen for schedule and routing risk, not area.

Cross-check: synth_phys chip area = 211,318.92 µm² (logic + wrapper sliver).
