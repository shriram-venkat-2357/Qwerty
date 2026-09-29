# Project Status & Handoff Report: Near-Memory Compute Accelerator SoC

## 1. Project Overview & Objectives
* **Project Title**: An Open-Source All-Digital Near-Memory Compute Accelerator for an RV32IM SoC, with a Reproducible Sky130 Energy-Measurement Methodology[cite: 3].
* **Target Technology**: Sky130 PDK (Standard Cell Library: `sky130_fd_sc_hd__tt_025c_1v80.lib`).
* **Core Objective**: Deliver a tapeout-ready, signoff-clean Sky130 GDSII of the accelerated SoC for Phase I[cite: 3]. The architecture includes an RV32IM_Zicsr core, an all-digital near-memory CNN accelerator tile, and a Sky130 pre-hardened SRAM macro serving as the IMEM/DMEM backing store[cite: 3].
* **Role Definition**: As Member C (Layout, Physical Checks, Software & ML Lead), your responsibilities include Yosys synthesis, OpenROAD physical design, DRC/LVS/antenna signoff, the OpenSTA power flow, and the ML software stack[cite: 3].

## 2. Current Status & Active Issues
The project is currently paused at the **Phase I Area Gate (G2)**[cite: 3]. Initial area calculations yielded a total chip footprint of 3,356,689.33 µm², which falsely triggered a failure against an assumed 180,973.73 µm² cap. 

* **The Root Cause (Memory Synthesis Bug)**: The massive 3.35M µm² footprint occurred because Yosys incorrectly synthesized the instruction and data memories (IMEM/DMEM) into millions of standard-cell flip-flops. 
* **Budget Misalignment**: The 180,973.73 µm² metric was Member A's isolated area probe for the 128x32 array alone, not the top-level die budget[cite: 3]. 
* **Architectural Fallback Paused**: Member A's fallback plan to reduce the array to a 128x16 configuration[cite: 3] is on hold. Cutting the array columns right now would degrade the accelerator without solving the underlying standard-cell memory bloat.

## 3. Completed Milestones 
* **Verification Pipeline Developed**: Engineered a robust, dynamic Python parsing script that successfully searches local `~/pdk` symlink directories, locates the target Sky130 `.lib` file, sanitizes string mismatches (stripping nested quotes), and perfectly matches standard cell instances from Yosys netlists.
* **Baseline Synthesis Executed**: Ran the baseline build-C synthesis, successfully matching 716 out of 758 cells, and extracted the raw standard-cell footprint.
* **Cross-Disciplinary Triage**: Successfully coordinated with the Processor & Accelerator Design Lead (Member A) to diagnose the memory synthesis bug and halt an unnecessary architectural downgrade.

## 4. Immediate Next Steps (Pre- and Post-Migration)
Before migrating to Antigravity, the following sequence must be executed to resolve the Area Gate and proceed with physical signoff.

* **Step 1: Commit Artifacts for Reproducibility**
  * Push the current `g2` Yosys synthesis script (including flags and memory sizes) and the corresponding `build/g2_stat.txt` to the Git repository. 
  * Document this as `docs/decisions/0003` to allow Member A to reproduce the baseline overrun.
* **Step 2: Blackbox the SRAM Macro**
  * Update the top-level Verilog and Yosys scripts to explicitly instantiate the Sky130 SRAM macro as a blackbox[cite: 3]. 
  * Ensure Yosys does not attempt to infer standard-cell registers for the memory arrays.
* **Step 3: Re-synthesize and Verify Logic Area**
  * Run the updated Yosys script to generate a clean `g2_stat.txt` without flip-flop memory bloat.
  * Execute the Python verification script to extract the true standard-cell logic area of the core and accelerator.
* **Step 4: Define True Die Budget & Floorplan**
  * Calculate the final SoC die budget by combining the newly verified logic area, the fixed physical footprint of the Sky130 SRAM macro, and standard padding for routing and power grids.
  * Execute the OpenROAD floorplan stage with the macro placed.
  * If this macro-inclusive floorplan still exceeds physical constraints, authorize Member A to merge the regression-green 128x16 fallback branch[cite: 3].
