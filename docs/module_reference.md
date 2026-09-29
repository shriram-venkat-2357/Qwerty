# Module Reference — Qwerty SoC (Phase I)

**Owner:** Shriram Kumar V (Member A)  
**Status:** Frozen (Week 6) · **Build:** `main`  
**Plan Reference:** §10.3 (Bus-factor mitigation), §2.1 (Architecture)

This document describes the hardware modules of the Qwerty SoC. It is intended for team members, reviewers, and anyone performing a clean-machine rebuild. All RTL is frozen; any changes require a logged decision in `docs/decisions/` and a full regression run.

---

## 1. Top-Level Architecture (`rtl/soc/soc_top.v`)

`soc_top` is the root module of the SoC. It instantiates the RV32IM core, the instruction and data memories (IMEM/DMEM), and the near-memory compute accelerator.

**Key Parameters & Interfaces:**
- **Clock/Reset:** `clk`, `rst_n` (active low).
- **Memory:** Currently inferred flip-flop arrays for simulation; targeted for Sky130 SRAM macro substitution in physical design (Plan §2.1).
- **Build Switch:** The accelerator is conditionally compiled using the `NMC` macro. 
  - `make sim BUILD=A` → Scalar RV32IM baseline.
  - `make sim BUILD=C` → Core + `nmc_unit` accelerator.

---

## 2. Processor Core (`rtl/core/`)

The core is a 5-stage in-order RV32IM_Zicsr pipeline.

### `rv32_pipeline.v`
The top-level core wrapper. It instantiates the pipeline registers, ALU, multiplier/divider, CSR unit, and forwarding logic.
- **Stages:** IF → ID → EX → MEM → WB.
- **Hazards:** Structural hazards on the register file are handled by the hazard unit. Data hazards are resolved via full forwarding.
- **Branches:** Resolved in the EX stage. Mispredictions flush the IF/ID and ID/EX registers.

### `forwarding_unit.v` & `pipeline_regs.v`
- **Forwarding:** Computes `fwd_rs1_data` and `fwd_rs2_data` by selecting between the register file output, EX/MEM ALU result, and MEM/WB memory data. *Critical fix (Week 5):* All forwarding consumers (ALU, branch compare, JALR, store data) must use these signals.
- **Pipeline Registers:** `if_id_reg`, `id_ex_reg`, `ex_mem_reg`, `mem_wb_reg`. They support synchronous flush and stall controls.

### `csr_unit.v`
Implements the machine-mode CSR subset required for traps and performance counters.
- **Supported CSRs:** `mtvec`, `mepc`, `mcause`, `mscratch`, `mstatus`, `mcycle`, `minstret`.
- **Trap Handling:** Supports `ecall` (cause 11) and illegal instruction (cause 2). Entry is via `mtvec` (direct mode only). Return via `mret`.

### `alu.v`, `muldiv.v`, `decoder.v`
- **ALU:** Standard RV32I arithmetic and logic operations.
- **Muldiv:** RV32M extension (MUL, MULH, DIV, REM). Implemented as a multi-cycle state machine.
- **Decoder:** Translates 32-bit instructions into control signals. Decodes the custom-0 opcode (`0x0B`) and routes it to the `xif_bridge`.

---

## 3. Accelerator Tile (`rtl/accel/`)

The `nmc_unit` is an all-digital, weight-stationary near-memory compute engine.

### `nmc_unit.v` (Top Accelerator)
Orchestrates the datapath. It holds the `ROWS × COLS` binary weights in a shift-register array.
- **Datapath Flow:** 
  1. **Popcount:** Per-column XNOR between weights and the activation vector.
  2. **Dot Product:** `dot = 2 * pc - ROWS`.
  3. **Shift-Accumulate:** `scaled = dot << shift_amt`; `acc = clr ? scaled : acc + scaled`.
  4. **Threshold & Pool:** Passed to sub-modules.
- **Packing:** Column 0 is in the LSBs of every vector. Activation vector is `ROWS/32` words wide.

### `nmc_psum.v`
Implements the shift-accumulate chain for all columns in parallel.
- **Inputs:** `pc_in` (popcount results), `shift_amt`, `clr`, `acc_en`.
- **Outputs:** `acc_out` (32-bit signed accumulator per column).

### `nmc_threshold.v`
Compares the accumulator against a per-column threshold.
- **Logic:** `act = (acc >= thr)` (signed, inclusive).
- **Configuration:** Thresholds are loaded via the `nmc.cfg` instruction (Decision 0002).

### `nmc_pool_reduce.v`
Implements 2×2 max pooling over 4 clock phases.
- **Logic:** Signed maximum. For binary activations, max is equivalent to a logical OR.

### `cim_sequencer.v`
The control FSM for the accelerator. It interfaces with the core via the `xif_bridge`.
- **States:** `IDLE`, `LDW` (Load Weights), `LDA` (Load Activations), `RUN` (Execute).
- **FIFO:** 64-word deep buffer for activations.
- **Issue Protocol:** Non-blocking issue (core waits in ID if busy). `nmc.rd` blocks until `done_q` is asserted.
- **Status CSR:** `0x7C0` = `{ready[3], error[2], done[1], busy[0]}`.

---

## 4. Dispatch & Interface (`rtl/accel/`)

### `xif_bridge.v`
A purely combinational bridge that translates the core's custom-0 decode signals into the `cim_sequencer` control inputs. It ensures the pipeline stalls correctly during `LDW`, `LDA`, and `RUN` operations.

---

## 5. Custom-0 ISA & Memory Map

Refer to `docs/memory_map.md` (D1) for the full specification.

| Instruction | funct3 | Semantics |
|---|---|---|
| `nmc.ldw` | `000` | Load weights from DMEM to array. `rs1`=base, `rs2`=row count. |
| `nmc.lda` | `001` | Load activations to FIFO. `rs1`=base, `rs2`=word count. |
| `nmc.run` | `010` | Execute one kernel position (popcount + psum + thresh + pool). |
| `nmc.rd`  | `011` | Read pooled result into `rd`. Blocks if busy. |
| `nmc.cfg` | `100` | Load per-column threshold. `rs1`=col, `rs2`=value. (Decision 0002) |

---

## 6. Synthesis & STA Flows

Refer to `scripts/` for the exact commands.

- **`synth_clean.ys`:** Full SoC synthesis. Audits for 0 latches and 0 multi-drivers. Maps to `sky130_fd_sc_hd`.
- **`synth_logic_only.ys`:** Black-boxes IMEM/DMEM to measure pure logic depth.
- **`soc_top.sdc`:** Defines the clock (40 ns baseline), false paths for async reset, and labelled exclusions for FF-mapped memory read muxes.

---

## 7. Known Limitations & Substitutions

1. **Memory:** IMEM/DMEM are inferred flip-flops in simulation. Physical design uses the Sky130 SRAM macro (Plan §2.1).
2. **Traps:** `mtvec` direct mode only. Misaligned loads/stores do NOT trap.
3. **Timing:** Full-netlist timing is memory-artifact-bound (~279 kHz). Logic-only depth is ~9 ns. HFN on `psum_clr` (253 ns) is P&R-fixable via buffer insertion.
