# Phase I — Status, Remaining Work, and Team Handoff
**Owner:** Shriram Kumar V (Member A — Processor & Accelerator Design Lead)
**Repo:** Qwerty · **Branches:** `main` (RTL frozen) + `g2-128x16` (held, green, unmerged)
**Plan reference:** Two-Phase Project Plan §4–§12 · **Status date:** Phase I, Week 7

---

## 1. Executive summary

- All Phase-I RTL owned by A is **written, regression-green, synthesis-clean and frozen on `main`**: RV32IM_Zicsr 5-stage core with machine-mode trap subset, `nmc_unit` accelerator tile, `xif_bridge` + `cim_sequencer` dispatch of the four custom-0 instructions, status CSR 0x7C0.
- Verification entry points (CI must point at these): `make sim BUILD=A|C`, `make sim_trap`, `make sim_nmc` — all green on the frozen commit.
- Synthesis/STA: **0 inferred latches, 0 multi-driver nets**; build-C gate area **1,746,602.63 µm²** with FF-mapped memories; full-netlist timing is **memory-artifact-bound (~279 kHz)**; logic-only netlist (memories black-boxed) shows **~9 ns logic depth** with a **253.7 ns HFN-dominated path** (`psum_clr`, 940 loads) that P&R buffering retires — not an RTL fix.
- Remaining Phase-I risk is **coordination-bound, not RTL-bound**: C's D4 weights (overdue Wk2), D8 harness (A+B), decision 0002 (`nmc.cfg`), decision 0003 (G2 final call), C's D9 energy numbers, B's D5 counts.

---

## 2. Work completed (week by week, with evidence)

### Weeks 1–2 — Spec freeze, core, area probe (D1, D3)
- Repository skeleton; single-Make-switch builds A/C (`-DNMC` = build C).
- **D1 frozen** (`docs/memory_map.md`): memory map; custom-0 opcode `0x0B`, R-type:
  `nmc.ldw` f3=000 (rs1 = byte base, rs2 = row count) · `nmc.lda` f3=001 (rs1 = base, rs2 = word count) · `nmc.run` f3=010 · `nmc.rd` f3=011 (rd = result). Status CSR **0x7C0 = {ready[3], error[2], done[1], busy[0]}**.
- Full 5-stage RV32I pipeline: forwarding unit, hazard unit, branch resolution (`rtl/core/rv32_pipeline.v`, `pipeline_regs.v`, `forwarding_unit.v`).
- **D3 area probe** (`reports/area_probe_report.txt`): 128×32 array+popcount = **180,973.568 µm²**; 128×16 = **96,457.5104 µm²**; **1,421.48005 µm²/row**; **5,282.2536 µm²/column**.

### Week 3 — M-extension, CSRs, traps
- `muldiv.v` (RV32M), `csr_unit.v` (Zicsr counters + trap CSR subset).
- Trap support: `csrrw/s/c` (+immediate forms), `mtvec/mepc/mcause/mscratch`, ecall (cause 11) + illegal-instruction (cause 2) entry, `mret`. Stated substitutions: **mtvec direct mode only; misaligned loads/stores do NOT trap**; pipeline bubbles decode as NOP.
- `tb/tb_trap.v` + `tb/program_trap.hex` → `make sim_trap`.

### Week 4 — Accelerator datapath (WP2)
- `nmc_psum.v` (dot = 2·pc − ROWS; scaled = dot <<< shift; acc = clr ? scaled : acc+scaled).
- `nmc_threshold.v` (act = (acc >= thr), signed, inclusive).
- `nmc_pool_reduce.v` (2×2 signed max over 4 phases, first/last framing).
- `nmc_unit.v` (ROWS×COLS stationary weight registers, per-column XNOR + popcount, shift-accumulate chain, KPOS mini-FSM).
- Standalone testbenches: `tb_psum`, `tb_threshold`, `tb_pool`, `tb_seq`, `tb_nmc`, `tb_muldiv`.

### Week 5 — Dispatch and integration (WP3, gate G4)
- `xif_bridge.v` (purely combinational), `cim_sequencer.v` (IDLE/LDW/LDA/RUN; 64-word FIFO; error semantics: lda count > 64, run with fcnt < 4), `dmem` port B.
- `nmc_unit` integrated into the pipeline under `-DNMC`; **non-blocking issue with ID-wait** (IF/ID stalls, ID/EX bubbles — an issue is never dropped); `nmc.rd` blocks in ID while busy and returns the result register.
- **Core-wide correctness fixes (G3-critical):** every forwarding consumer (ALU, branch compare, JALR, store data) now uses `fwd_rs1_data/fwd_rs2_data`; **regfile write-through bypass** fixes distance-3 dependencies; IF/ID-vs-ID/EX flush split fixes the wait-kills-instruction bug.
- `tb/tb_nmc_instr.v` + `tb/program_nmc.hex` → `make sim_nmc`: weights dmem→array, activations dmem→FIFO→datapath, **acc = 256, rd = 0, status = 0xA** — all checks green.

### Week 6 — Synthesis cleanup, freeze, first STA
- `scripts/synth_clean.ys`: audit clean (0 latches after branch-comparator `default`, 0 multi-drivers, `check -assert` clean); build-C gate area **1,746,602.63 µm²** (FF-mapped IMEM/DMEM dominate).
- **Packed-array refactor** of `wmem/acc/thr/fifo` so the Yosys→OpenSTA netlist is parseable; TB references updated to part-selects (`wmem[r*COLS +: COLS]`, `acc[j*ACC_W +: ACC_W]`).
- **RTL freeze declared on `main`**: fixes only, each with a logged decision and full regression.
- `scripts/soc_top.sdc` + `scripts/run_sta.tcl`: async-reset false path; **labelled FF-memory-read exclusions** (`-through *mem_rdata* / *instr* / *b_rdata*`). Full-netlist worst path = dmem read mux (`mem_alu_result` drives 8,272 loads / 37.7 pF; arrival 3,582.9 ns ⇒ ~279 kHz) — declared an SRAM-macro-substitution artifact per §2.1, not hidden.
- Logic-only flow: `scripts/synth_logic_only.ys` (imem/dmem black-boxed) + `scripts/run_sta_logic_only.tcl` + `strip_mem.py`; worst path **253.7 ns = HFN on `psum_clr`** (940 loads, 2.09 pF); pure logic depth ≈ 6 gates ≈ 9 ns.
- `reports/` committed (area probe + both timing reports); `.gitignore` for `build/` and editor swap files.
- `docs/energy_table.md`: G5 schema with §9.2 rules (kernel-only vs end-to-end, leakage vs dynamic, SoC vs `u_nmc_unit`), internal-consistency checklist, proxy fallback.

### Week 7 (in progress) — G2 governance and decisions
- Rejected an invalid G2 trigger from C (the "budget cap" was A's own D3 array probe; the true overrun culprit is FF-mapped memory, not the array; her 3.36 M µm² did not reconcile with the committed 1.75 M µm²). C accepted the corrected sequence: commit her g2 scripts, integrate the SRAM macro, supply die budget + macro-inclusive floorplan.
- **Branch `g2-128x16` prepared and regression-green** (COLS=16 + TB width fixes), held unmerged pending decision 0003.
- **`docs/decisions/0002-nmc-cfg-threshold-load.md` drafted**: `nmc.cfg` at unused funct3 `3'b100` (rs1 = column, rs2 = threshold) — awaiting B/C ack.
- Post-CTS STA triage cadence agreed with C (RTL-fixable vs P&R-fixable; HFN buffering is P&R's job).

---

## 3. Frozen semantics reference (code against this)

- **Dispatch:** one issue accepted per IDLE entry; instructions wait in ID while busy; `rd` blocks; done/error sticky until next issue.
- **Datapath:** per-column pc = Σ XNOR(w, act); dot = 2·pc − ROWS; scaled = dot <<< shift; acc = clr ? scaled : acc+scaled (clr at kernel position 0); act = (acc >= thr) signed inclusive; pool = signed max over 4 phases (max ≡ OR on binary acts).
- **Packing:** column 0 in the LSBs of every vector; activation vector = ROWS/32 words (4 at ROWS=128); FIFO depth 64; KPOS = 9 default.
- **Integrated build ties `we_thr = 0`, `shift_amt = 0`** until decision 0002 merges — randomised tests must model thr = 0 / shift = 0 or use standalone `nmc_unit` ports.
- **Stated limitations:** mtvec direct only; no misaligned trap; IMEM/DMEM inferred in simulation netlists (SRAM macro substitution pending with C per §2.1).

---

## 4. Remaining work to complete Phase I (A-owned and shared)

| # | Item | Plan ref | Owner | Blocked on |
|---|------|----------|-------|------------|
| 1 | D8 end-to-end CNN: layer-loop driver, staging, golden.txt bit-exact diff TB, phase markers | §4.1, D8 (due Wk5) | A+B | C's D4 weights + threshold vector |
| 2 | Implement `nmc.cfg` after ack: sequencer f3=100 → `we_thr` pulse; TB; D1 addendum; regression | decision 0002 | A | B/C ack |
| 3 | G2 final call: merge `g2-128x16` or retire it; record µm²/column either way | §5.2, decision 0003 | A (C confirms floorplan) | C's macro floorplan + die budget |
| 4 | Code-review C's golden model before B randomises against it | §10.3, D7 | A | C's D7 |
| 5 | Post-CTS STA triage loop: logged RTL fixes + regression; freeze otherwise | Wk7 column | A | C's post-CTS reports |
| 6 | Verify G5/D9: energy table filled per §4.2/§9.2 or labelled proxies; run consistency checklist | G5, D9 | A verifies, C produces | C's OpenSTA run, B's VCDs |
| 7 | Chase B: D5/G3 counts on frozen main; D7b; sequencer SVA; phase-marked gate-level VCDs (A and C) | D5, D7b, Wk6 | B | — |
| 8 | Week-8 column: `docs/module_reference.md`, integration notes, repo tidy, D12 architecture/RTL sections, accuracy-statement coordination | §10.3, Wk8 | A | — |
| 9 | Signoff support: hold freeze; §4.3 reproducibility (`make gds` clean checkout) with C; tool-version pin check | §4.3 | A+C | C's P&R |
| 10 | Gap: v1.0 tag; D13 clean-machine rebuild (A runs C's flow); Phase-II `tile_sequencer` FSM spec | §6, D13 | A+C | Phase I close |

---

## 5. Teammate leads (from what is already on `main`)

### 5.1 For B — Yugal Kishore E (Verification, Hardware Testing & Energy Cross-Check)
Pull `main` first. CI matrix entry points: `make sim BUILD=A|C`, `make sim_trap`, `make sim_nmc`.
Conventions: packed-array part-selects (§3); thr = 0 / shift = 0 in the integrated build until 0002 merges; packing col0-at-LSB; sequencer error semantics; status CSR bit layout. COLS may become 16 if 0003 triggers — branch `g2-128x16` shows the TB-width pattern.
Queue:
1. **Now:** full `rv32ui-p` / `rv32um-p` re-run on the frozen commit → counts in CI (closes D5/G3; the forwarding and regfile fixes landed after your last baseline).
2. **Now:** sequencer SVAs (never leave IDLE without valid opcode; never done while busy; every start eventually completes).
3. **With A:** D8 harness (driver + golden-diff TB + phase markers).
4. **After A's D7 review:** D7b randomised RTL-vs-model.
5. **Week-6 item still open:** gate-level SDF testbench with phase markers (weight load / activation load / conv / threshold / pool / readback); per-phase VCDs for builds A and C — feeds C's D9 and your D10.
6. **Week 7:** D10 ½·C·V²·α cross-check from C's SPEF; RTL inference run feeding the accuracy table (consumes the D8 harness).
7. **Week 8:** verification report (waveforms, CI badge, counts, coverage) for D12.

### 5.2 For C — Vanmathi Samikkannu (Layout, Physical Checks, Software & ML)
Inputs on `main`: frozen RTL commit; `scripts/synth_clean.ys`, `synth_logic_only.ys`, `run_sta.tcl`, `run_sta_logic_only.tcl`, `strip_mem.py`; `reports/` (area + both timing reports); `docs/energy_table.md` schema.
Queue:
1. Commit your g2 Yosys script + `g2_stat.txt` (§4.3 reproducibility) and reconcile 3.36 M vs the committed 1.75 M µm² (flags, corner, memory sizes).
2. SRAM-macro integration (black-box in synthesis/STA); deliver die budget + macro-inclusive floorplan → A's G2 call (0003).
3. P&R of build C: HFN buffering (`set_max_fanout`) for `psum_clr` / `act_valid` — the 253.7 ns path is P&R-fixable, not RTL; send post-CTS STA reports to A on the agreed cadence.
4. **D4 (overdue since Wk2, blocks D8 and F1):** `weights.hex` + `golden.txt` + the exact per-column threshold vector. **D7** golden model → to A for code review before B touches it.
5. **D9:** per-phase energy into `docs/energy_table.md` per §4.2/§9.2 (leakage vs dynamic; SoC vs `u_nmc_unit`; kernel-only vs end-to-end); G5 proxy fallback if the flow slips.
6. SPEF extraction → B for D10.
7. Weeks 7–8: full P&R → D11 `soc_top.gds` + signed §4.3 checklist; pin tool versions; tag v1.0; lead D12.
8. Gap: D13 pair-run — A rebuilds your flow on a clean machine.
If 0003 triggers the fallback: re-probe and record µm²/column (both sizes already measured in D3).

---

## 6. Open decisions and standing risks

- **0002 (`nmc.cfg`)** — awaiting ack; unblocks real thresholds for D8.
- **0003 (G2)** — awaiting C's macro floorplan + die budget; `g2-128x16` held green meanwhile.
- **SRAM macro vs FF memory** — macro is the §2.1 design; if OpenROAD cannot route with it, the inferred-FF fallback must be stated plainly (§12).
- **HFN on `psum_clr`** — P&R-fixable; do not "fix" in RTL without a logged decision.
- **D4 delay** — largest schedule risk to F1; escalate at Monday standup until a date exists.
- **Claim discipline (§9.2, §12):** report the logic-only frequency with the macro-pending label; never claim 50 MHz unless closed; never quote C÷A alone; never present kernel-only energy as end-to-end; never call it compute-in-memory.

---

## 7. Quick reference

    make sim BUILD=A                          # scalar smoke
    make sim BUILD=C                          # + nmc_unit smoke
    make sim_trap                             # trap/CSR test
    make sim_nmc                              # instruction-level accelerator test
    yosys -s scripts/synth_clean.ys           # build-C synthesis + latch/multi-driver audit
    yosys -s scripts/synth_logic_only.ys      # memory-black-boxed logic netlist
    sta -no_init -exit scripts/run_sta.tcl             # full-netlist STA
    sta -no_init -exit scripts/run_sta_logic_only.tcl  # logic-only STA

**Freeze rule:** no functional change to `rtl/` without a logged decision in `docs/decisions/` plus a full regression run. Every number above is regenerable from the repository with the commands in this section.
