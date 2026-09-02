# EC22711 SoC — Team Reference README

**Project:** An Open-Source All-Digital Near-Memory Compute Accelerator for an RV32IM SoC,
with a Reproducible Sky130 Energy-Measurement Methodology (Sky130, 130 nm).
**Course:** EC22711 UG Project, Phase I & II · **Supervisor:** Dr. Ayyappan G

**Team**
| Member | Role | Owns |
|---|---|---|
| A — Shriram Kumar V | Processor & Accelerator Design Lead | `rtl/**`, custom-0 ISA spec, area probe, build switch, integration |
| B — Yugal Kishore E | Verification, Hardware Testing & Energy Cross-Check Lead | `tb/**`, CI, riscv-tests, SVA, gate-level sim, energy cross-check |
| C — Vanmathi Samikkannu | Layout, Physical Checks, Software & ML Lead | physical flow, PDK, signoff, GDS, golden model, driver, ML flow |

**Remote:** `https://github.com/shriram-venkat-2357/Qwerty.git` (branch `main`)
**Scope of this README:** all work completed by Member A (Weeks 1–3), as a reference for B and C.

---

## 0. Quick start (simulate in 3 commands)

```bash
git clone https://github.com/shriram-venkat-2357/Qwerty.git && cd Qwerty
mkdir -p build
iverilog -o build/pipeline.vvp rtl/core/regfile.v rtl/core/decoder.v rtl/core/alu.v \
  rtl/core/alu_control.v rtl/core/control_unit.v rtl/core/imem.v rtl/core/dmem.v \
  rtl/core/pipeline_regs.v rtl/core/forwarding_unit.v rtl/core/muldiv.v \
  rtl/core/csr_unit.v rtl/core/rv32_pipeline.v tb/tb_pipeline.v
vvp build/pipeline.vvp
```

---

## 1. Directory map

```
.
├── README.md                  ← this file
├── program.hex                ← 9-instruction smoke-test program (IMEM init)
├── rtl/
│   ├── core/
│   │   ├── rv32_fetch_decode_stub.v   # Week-1 IF skeleton (superseded, kept for history)
│   │   ├── regfile.v                  # 32×32 register file, x0 hardwired 0
│   │   ├── decoder.v                  # field split + I/S/B/U/J immediate extraction
│   │   ├── alu.v                      # ADD SUB AND OR XOR SLL SRL SRA SLT SLTU + zero flag
│   │   ├── alu_control.v              # funct3/funct7/alu_op → ALU opcode
│   │   ├── control_unit.v             # main control; includes custom-0 NOP stub (Week 4 hook)
│   │   ├── imem.v                     # 256×32, $readmemh("program.hex")
│   │   ├── dmem.v                     # 1024 B, LB/LH/LW/LBU/LHU, SB/SH/SW
│   │   ├── rv32_single_cycle.v        # single-cycle reference model (cross-check)
│   │   ├── pipeline_regs.v            # IF/ID, ID/EX, EX/MEM, MEM/WB registers (stall/flush)
│   │   ├── forwarding_unit.v          # EX/MEM→EX and MEM/WB→EX forwarding
│   │   ├── rv32_pipeline.v            # 5-stage in-order pipeline top (current core)
│   │   ├── muldiv.v                   # RV32M, single-cycle, spec-correct corner cases
│   │   └── csr_unit.v                 # Zicsr: cycle/cycleh/instret/instreth (read-only)
│   └── accel/
│       └── nmc_array_popcount.v       # parameterised ROWS×COLS binary-weight array + popcount (area probe)
├── tb/
│   ├── tb_fetch_decode_stub.v
│   ├── tb_single_cycle.v
│   ├── tb_pipeline.v
│   └── tb_muldiv.v                    # RV32M corner-case unit test
├── scripts/
│   └── area_probe.ys                  # Yosys synthesis → Sky130 HD area (see §6)
└── docs/
    ├── isa_spec.md                    # D1 — custom-0 ISA (FROZEN draft v0.1)
    ├── memory_map.md                  # D1 — memory map (FROZEN draft v0.1)
    ├── area_probe_report.md           # D3 — area numbers
    └── tool_versions.txt              # pinned tool versions
```

Ownership rule (plan §10.1/§10.4): `rtl/**` is A, `tb/**` and CI are B, physical/PDK scripts are C.
The smoke testbenches in `tb/` were starter files by A; **B is free to replace/extend them** with the
self-checking harness and riscv-tests runner.

---

## 2. Frozen specifications (B and C: read first)

### 2.1 Custom-0 ISA (docs/isa_spec.md)

Opcode `0001011` (custom-0), **R-type**, all `funct7 = 0000000`:

| Instruction | funct3 | Operands | Behaviour |
|---|---|---|---|
| `nmc.ldw` | 000 | rs1 = weight base addr, rs2 = word count | non-blocking weight load into array |
| `nmc.lda` | 001 | rs1 = activation base addr, rs2 = word count | non-blocking activation load |
| `nmc.run` | 010 | rs1 = layer config / op selector | non-blocking start of conv/threshold/pool |
| `nmc.rd`  | 011 | rd = result/status | **blocking** read-back |

Status CSR: **0x7C0 `nmc_status`** — bit0 busy, bit1 done, bit2 error, bit3 ready.
Software dispatch uses `.insn r` inline assembly — **no toolchain patch**.

### 2.2 Memory map (docs/memory_map.md)

| Range | Region |
|---|---|
| 0x0000_0000–0x0001_FFFF | IMEM (Sky130 SRAM macro) |
| 0x0002_0000–0x0003_FFFF | DMEM (Sky130 SRAM macro) |
| 0x1000_0000 | UART / putchar (address to be confirmed with C) |
| 0x4000_0000–0x4000_0FFF | optional accelerator debug MMIO (may be dropped) |

### 2.3 Machine CSRs implemented (csr_unit.v)

`cycle` 0xC00 · `cycleh` 0xC80 · `instret` 0xC02 · `instreth` 0xC82 (read-only).
`instret` increments when a real instruction enters the pipeline (`~if_stall & ~id_flush`).

---

## 3. RTL module reference — current core (`rv32_pipeline.v`)

* **Pipeline:** 5-stage in-order IF→ID→EX→MEM→WB.
* **Forwarding:** `forwarding_unit.v` — `forward_a/b`: `00` = regfile, `01` = from MEM/WB
  (`wb_write_data`), `10` = from EX/MEM (`mem_alu_result`, higher priority).
* **Hazards:** only **load-use** stalls (1 cycle): `ex_mem_read && ex_rd!=0 && ex_rd∈{id_rs1,id_rs2}`
  (LUI/AUIPC excluded). Everything else is handled by forwarding.
* **Control hazards:** branch condition evaluated in EX; taken-branch/jump resolved in MEM and
  flushes IF+ID (2-cycle penalty). `branch_flush = (mem_branch && mem_branch_taken) || mem_jump`.
* **EX result MUX:** `ex_result = M-ext ? muldiv : CSR ? csr_rdata : ALU`.
  - M-ext detect: `opcode==0110011 && funct7==0000001`.
  - CSR detect: `opcode==1110011`.
* **RV32M (`muldiv.v`):** MUL, MULH, MULHSU, MULHU, DIV, DIVU, REM, REMU.
  Corner cases per spec: div-by-zero → `-1`; rem-by-zero → dividend;
  `INT_MIN / -1` → `INT_MIN`; `INT_MIN % -1` → `0`.
* **Custom-0 stub:** `control_unit.v` recognises `0001011` and executes **NOP** for now.
  Week 4 replaces this with the real `nmc_unit` dispatch (xif_bridge).
* **Style:** synchronous resets, no intentional latches, no multi-driver nets
  (target: `verilator --lint-only` clean — C's flow depends on this).

---

## 4. Simulation commands

```bash
# Single-cycle reference model
iverilog -o build/single_cycle.vvp rtl/core/regfile.v rtl/core/decoder.v rtl/core/alu.v \
  rtl/core/alu_control.v rtl/core/control_unit.v rtl/core/imem.v rtl/core/dmem.v \
  rtl/core/rv32_single_cycle.v tb/tb_single_cycle.v && vvp build/single_cycle.vvp

# 5-stage pipeline (current core, includes RV32M + Zicsr)
iverilog -o build/pipeline.vvp rtl/core/regfile.v rtl/core/decoder.v rtl/core/alu.v \
  rtl/core/alu_control.v rtl/core/control_unit.v rtl/core/imem.v rtl/core/dmem.v \
  rtl/core/pipeline_regs.v rtl/core/forwarding_unit.v rtl/core/muldiv.v \
  rtl/core/csr_unit.v rtl/core/rv32_pipeline.v tb/tb_pipeline.v && vvp build/pipeline.vvp

# RV32M unit test (expect: ALL MULDIV TESTS PASSED)
iverilog -o build/tb_muldiv.vvp rtl/core/muldiv.v tb/tb_muldiv.v && vvp build/tb_muldiv.vvp

# Lint
verilator --lint-only rtl/core/rv32_pipeline.v
```

Notes for B:
* `imem.v` loads `program.hex` **relative to the directory you run `vvp` from** — run from repo root.
* Register file is visible hierarchically as `u_cpu.u_regfile.regs` for self-checking/tohost wiring.
* Stall/flush observables: `u_cpu.if_stall`, `u_cpu.id_flush`.

---

## 5. Test program (`program.hex`)

```
00100093  addi x1,x0,1     00200113  addi x2,x0,2
002081B3  add  x3,x1,x2    00308233  add  x4,x1,x3
0001A023  sw   x1,0(x3)    00012283  lw   x5,0(x2)
00528293  addi x5,x5,5     0002A023  sw   x5,0(x5)
00000063  beq  x0,x0,0     (end loop)
```

---

## 6. Synthesis / area probe (D3)

**Liberty file (not in the repo):** `~/pdk/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib`
(12.7 MB, 452 cells). Source: GitHub mirror `praharshapm/vsdmixedsignalflow` `LIB/` folder —
the official `google/skywater-pdk-libs-*` repos contain only per-cell JSON, **no combined .lib**.
If missing on your machine, re-download or use `volare enable sky130`.

**Flow (`scripts/area_probe.ys`):**
`read_verilog → hierarchy → proc → opt → memory → opt → flatten → opt → techmap → opt
→ dfflibmap -liberty → abc -liberty → opt → stat -liberty`
⚠️ `techmap` **must** come before `abc`, otherwise ABC maps 0 gates.

```bash
yosys -s scripts/area_probe.ys 2>&1 | grep "Chip area"
# size variants for per-row / per-column:
yosys -p "... hierarchy -top nmc_array_popcount -chparam ROWS 64 ..." | grep "Chip area"
yosys -p "... hierarchy -top nmc_array_popcount -chparam COLS 16 ..." | grep "Chip area"
# µm²/row = (A128x32 − A64x32)/64 ;  µm²/col = (A128x32 − A128x16)/32
```

---

## 7. Results obtained so far

| Item | Result |
|---|---|
| Area probe, 128×32 array+popcount, Sky130 HD tt | **180,973.568 µm² (≈0.181 mm², ≈44 µm²/bit)** |
| Pipeline vs single-cycle | identical architectural results; stalls now only on load-use |
| RV32M unit test | spec corner cases covered (div0/overflow) |

---

## 8. Verification status matrix

| Block | Status |
|---|---|
| Fetch/decode stub (Wk1) | ✅ simulated |
| Single-cycle RV32I | ✅ simulated (program.hex) |
| Pipeline, naive stall | ✅ simulated |
| Pipeline + forwarding + load-use stall + branch flush | ✅ simulated |
| `muldiv` | ✅ unit test written — run `tb_muldiv` |
| `csr_unit` | ✅ integrated in EX MUX |
| **riscv-tests rv32ui-p / rv32um-p** | ⏳ **pending — B's harness, Gate G3 (Week 3)** |
| Area probe 64×32 / 128×16 | ⏳ commands ready (§6), completes D3 |

---

## 9. Notes for B

1. Build the golden model and `.insn r` driver from `docs/isa_spec.md` — encodings are frozen.
2. `rv32_pipeline.v` is the DUT for riscv-tests; M-ext and CSRs are already in the EX MUX, so
   `rv32um-p` will exercise `muldiv` directly.
3. Report any core bug to A immediately — **G3 rule: all feature work stops until tests are green.**

## 10. Notes for C

1. Area number for G2 floorplan: 180,973.568 µm² at 128×32 (per-row/col follow this week).
2. RTL is written latch-free/multi-driver-free on purpose; pair-run of the physical flow is
   scheduled Week 3 (plan §10.3) — A runs the flow, you watch.
3. Reuse `scripts/area_probe.ys` and the liberty path for your own runs; keep tool versions pinned
   in `docs/tool_versions.txt`.

---

## 11. Environment setup (replicate on B/C machines)

```bash
sudo apt update && sudo apt install -y git nano make build-essential iverilog verilator yosys
sudo apt install -y gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf   # if available
# RV32 wrapper (plan uses riscv32-unknown-elf-gcc):
mkdir -p ~/bin && cat > ~/bin/riscv32-unknown-elf-gcc <<'EOF'
#!/usr/bin/env bash
exec riscv64-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 "$@"
EOF
chmod +x ~/bin/riscv32-unknown-elf-gcc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

---

## 12. Conventions

* Branch `main`; **Wednesday integration checkpoint — nothing merges unbuilt.**
* Commit style: `git commit -m "Week N: <what> (<deliverable id>)"`.
* Never two people editing the same module in the same week.
* Every Friday: commit one artifact (log/report/waveform/table).

## 13. Known gotchas (lessons learned — do not repeat)

1. `reg` cannot be driven by `assign` (use `wire`) — caused our only pipeline compile error.
2. Yosys: **`techmap` before `abc`**, else "Extracted 0 gates".
3. Google skywater repos have **no combined liberty**; use the mirror or volare.
4. `wget -O` does **not** create a file on 404 — always verify with `ls -l` + `head`.
5. `git push` fails with "src refspec main does not match any" if nothing was committed yet.

## 14. Pending / next (A)

1. Finish D3: run 64×32 and 128×16 probes, fill `docs/area_probe_report.md`, hand numbers to C (G2).
2. G3: fix any riscv-tests failures B reports (Week 3, Review 1).
3. Week 4: `nmc_unit` datapath (array, XNOR+popcount, psum, threshold, pool_reduce) +
   Make switch for builds A/C.
