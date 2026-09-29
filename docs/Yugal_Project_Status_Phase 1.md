# Project Status & Phase 1 Handoff Document
**Author:** Yugal (Verification Lead)  
**Date:** September 28, 2026  
**Branch:** `verif/rtl-fixes` (Latest commits: `f0b0311`, `ef06b3d`)

---

## 1. Executive Summary
Phase 1 verification, gate-level synthesis, and power-analysis scaffolding are largely complete. The RTL has been verified against the Week 5/6 specifications, and a robust gate-level simulation flow has been built from scratch. We have successfully generated phase-marked VCDs for the G5 Energy Table. However, the D7/D8 End-to-End (E2E) CNN deliverables are currently blocked by placeholder artifacts in `main`. This document outlines completed work, remaining tasks for Phase 1, and critical action items for the RTL and Power/Software teams.

---

## 2. Completed Work (Verification & Infrastructure)

### A. RTL Verification & Bug Fixes (Weeks 4 & 5)
*   **Merge Conflict Resolution:** Resolved upstream merge conflicts in `rtl/core/rv32_pipeline.v` in favor of the frozen Week 5 RTL.
*   **Regression Testing:** Verified fixes for Bugs 3-8 against the new RTL. Full regression suite passes with baseline cycle counts.
*   **SVA Deliverable:** Added Verilog-compatible `always` block assertions to `rtl/accel/cim_sequencer.v` to catch invalid `funct3` in IDLE and `done_q` asserted while busy. Wrapped in `` `ifndef SYNTHESIS `` to ensure synthesis compatibility.

### B. Gate-Level Synthesis Flow (Week 6)
*   **Synthesis Scripts:** Built the Yosys/ABC synthesis flow from scratch (`scripts/synth_clean.ys` and `scripts/synth_clean_c.ys`) because the referenced script was missing from the repo.
*   **Synthesis-Clean RTL:** Patched simulation-only `$error` tasks in `cim_sequencer.v` to make the RTL synthesis-clean.
*   **Netlist Generation:** Successfully generated 13MB gate-level netlists for both Build A (`build/soc_gate.v`) and Build C (`build/soc_gate_c.v`).
*   **Functional Gate-Level Sim:** Created `tb/tb_soc_gate.v`. Both builds passed functional gate-level simulation (`pc=0x24`), proving the synthesized logic is functionally equivalent to the RTL.

### C. G5 Energy Table & Power Analysis Scaffolding
*   **Phase-Marked VCDs:** Created `tb/tb_power.v` to monitor preserved NMC control signals (`seq_we_row`, `seq_act_valid`, `seq_busy`, `seq_done`) in the gate-level netlist.
*   **Mixed-Mode Simulation:** Implemented a robust mixed-mode simulation flow (gate-level logic + behavioral memories) to allow `$readmemh` to load hex files during gate-level simulation.
*   **Phase Logging:** The testbench automatically logs rising-edge timestamps for WEIGHT_LOAD, ACT_LOAD, COMPUTE, and READBACK phases to `build/power_phases.log` for Vanmathi's power windowing.

### D. Upstream Test Harness Infrastructure
*   **Memory Resizing:** Resized `imem.v` from 1 KB to 16 KB to accommodate larger test programs.
*   **RISC-V Tests:** Patched the upstream `riscv-tests` Makefile and linker script to load at `0x00000000`. Successfully generated `.hex` files (Note: Upstream `rv32ui` contains RV64 wrappers, requiring future filtering for our RV32 core).

---

## 3. Next Steps to Complete Phase 1 (Yugal)

1.  **Finalize G5 Power VCDs:** 
    *   Run the final mixed-mode simulation for Build A using the cleaned netlist and `tb_power.v`.
    *   Commit the final `build/power.vcd` and `build/power_phases.log` for both Build A and Build C.
2.  **SDF Timing Annotation:** 
    *   Once Vanmathi/Shriram provides the Liberty (`.lib`) and SDF (`.sdf`) files, integrate them into `tb_power.v` using `$sdf_annotate` to transition from functional gate-level sim to true timing-annotated power analysis.
3.  **D7b/D8 E2E Integration (Pending Artifacts):** 
    *   Once the team provides the finalized bit-accurate golden model and the full CNN layer assembly driver, build the randomized DPI-C testbench for RTL-vs-Golden comparison and the full E2E CNN testbench.

---

## 4. Action Items & Handoff for Teammates

### 🛑 For Shriram (RTL & Synthesis Lead)
1.  **Fix Hardcoded PDK Paths in Synthesis Scripts:** 
    *   The current `scripts/synth_clean.ys` and `synth_clean_c.ys` contain hardcoded paths to your local machine (e.g., `/home/shriram_venkat/pdk/sky130_fd_sc_hd/...`). This causes Yosys `abc` and `dfflibmap` to fail on other machines. 
    *   *Action:* Please push a version of the synthesis scripts that uses relative paths or environment variables for the PDK, or provide the OpenROAD flow scripts that generate the SDF.
2.  **Provide SDF and Liberty Files:** 
    *   The G5 power analysis requires SDF files for true timing annotation. Please commit the `.sdf` and `.lib` files generated from your area-probe/STA runs to the `libs/` or `build/` directory.
3.  **Finalize D8 E2E Assembly:** 
    *   `tests/program_e2e.S` is currently just a 5-instruction smoke test. Please provide the complete assembly driver that loops through a full CNN layer (Weight Load -> Act Load -> Conv -> Thresh -> Pool -> Readback).

### 🛑 For Vanmathi / C (Power, Software & Golden Model Lead)
1.  **Finalize the D7 Golden Model:** 
    *   `verif/nmc_golden.c` is currently a 4-iteration hardcoded stub, and `training/golden.txt` is only 9 bytes (`00000001`). 
    *   *Action:* Please push the actual bit-accurate C model that implements the full 128x64 1-bit CiM SRAM array math, and the actual LeNet `weights.hex` and `golden.txt` artifacts. I cannot build the randomized RTL-vs-Golden testbench until these are finalized.
2.  **Consume G5 Power VCDs:** 
    *   I have generated `build/power.vcd` and `build/power_phases.log` using the `sim_nmc` synthetic layer. 
    *   *Action:* Use the cycle timestamps in `power_phases.log` to window your power analysis in PrimeTime/Innovus. Note that these VCDs are currently *functional* (no SDF delays). Once you provide the SDF, I will regenerate them with true timing delays.

---

## 5. Repository Structure & Key Files Reference

| File/Directory | Description | Status |
| :--- | :--- | :--- |
| `rtl/core/rv32_pipeline.v` | Core pipeline (Week 5 frozen RTL) | ✅ Verified |
| `rtl/accel/cim_sequencer.v` | NMC Sequencer (Assertions added) | ✅ Synthesis-clean |
| `scripts/synth_clean.ys` | Yosys synthesis script (Build A) | ⚠️ Needs PDK path fix |
| `scripts/synth_clean_c.ys` | Yosys synthesis script (Build C/NMC) | ️ Needs PDK path fix |
| `tb/tb_soc_gate.v` | Gate-level smoke testbench | ✅ Passed |
| `tb/tb_power.v` | G5 Power phase-monitoring testbench | ✅ Mixed-mode ready |
| `verif/nmc_golden.c` | C Golden Model for NMC | 🛑 Placeholder (Needs C) |
| `tests/program_e2e.S` | D8 E2E Assembly Driver | 🛑 Placeholder (Needs Shriram) |
| `build/soc_gate_c.v` | Generated Gate-level Netlist (Build C) | ✅ Generated (13MB) |
| `build/power.vcd` | G5 Power VCD (Synthetic Layer) | ✅ Generated |

---
*End of Document. Please review your respective action items and update the team channel once the artifacts are pushed to `main`.*
