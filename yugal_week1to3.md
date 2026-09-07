# EC22711 SoC — Member B (Yugal) Status: Weeks 1–3

**Project:** An Open-Source All-Digital Near-Memory Compute Accelerator for an RV32IM SoC,
with a Reproducible Sky130 Energy-Measurement Methodology
**Role:** Verification, Hardware Testing & Energy Cross-Check Lead
**Scope of this file:** all work completed by Member B (Weeks 1–3), as a reference for A and C.

---

## 0. Quick start (reproduce my environment)

```bash
sudo apt update && sudo apt install -y git gcc unzip python3-pip python3-venv \
  iverilog gtkwave verilator yosys gcc-riscv64-unknown-elf binutils-riscv64-unknown-elf

# RV32 wrapper (only the 64-bit toolchain is in apt)
mkdir -p ~/bin && cat > ~/bin/riscv32-unknown-elf-gcc <<'EOF'
#!/usr/bin/env bash
exec riscv64-unknown-elf-gcc -march=rv32im_zicsr -mabi=ilp32 "$@"
EOF
chmod +x ~/bin/riscv32-unknown-elf-gcc
echo 'export PATH="$HOME/bin:$PATH"' >> ~/.bashrc && source ~/.bashrc
```

---

## 1. What I found running the existing RTL — 2 blockers

### 1.1 Pipeline deadlock on back-to-back ALU dependencies

Running the README's own quick-start command against `rv32_pipeline.v`, the core
gets stuck permanently at `PC=0x0000000c` from cycle 4 onward (`Stall=1` forever,
times out at cycle 400 without finishing the 9-instruction smoke test).

**Root cause:** `rv32_pipeline.v` (~line 228) still contains the block literally
commented `"NAIVE HAZARD DETECTION (stall on any dependency) / No forwarding yet"`.
This predates `forwarding_unit.v` being added — `forwarding_unit` is correctly wired
into the EX stage, but `if_stall`/`id_stall` are still driven by the old naive logic
that stalls on *any* register dependency, not just load-use. Since `id_stall` also
freezes the ID/EX register, the dependent instruction just recirculates in EX
forever — the hazard condition never clears. It's a deadlock, not a 1-cycle penalty.

**Suggested fix:**
```verilog
wire load_use_hazard = ex_mem_read && (ex_rd != 5'd0) &&
                        ((ex_rd == id_rs1) || (ex_rd == id_rs2));
```
Drive `if_stall`/`id_stall` from this instead, and let `forwarding_unit` handle
everything else, as intended. **Status: reported to A, awaiting fix.**

### 1.2 riscv-tests cannot boot on this core yet

Disassembling the compiled `rv32ui-p-add` test shows every test's `reset_vector`
requires `csrw mtvec/mepc/mstatus/pmpaddr0/pmpcfg0/satp/medeleg/mideleg/mie`, plus
`mret` and `ecall` — a real machine-mode trap subsystem. `csr_unit.v` currently only
implements **read-only** `cycle`/`instret`. The standard suite's pass/fail signaling
works *through* an `ecall`-triggered trap that writes to `tohost`, so without trap
support, literally zero tests can run — independent of bug 1.1.

**Two options, needs a team decision:**
- **(A)** A adds real trap/CSR-write support (`mtvec`, `mret`, `ecall` decode, trap
  redirection) — matches the plan's G3 wording exactly, but is real new RTL scope.
- **(B)** B (me) writes a custom reduced `riscv_test.h`/`link.ld` that signals
  pass/fail via a direct memory write instead of ecall+trap — faster to unblock,
  but technically not the literal stock suite.

**Status: open, blocking D5 (Gate G3, Week 3).**

---

## 2. Draft work completed (Weeks 1–2)

### 2.1 NMC golden model + bare-metal driver (`verif/`)

- `nmc_golden.h` / `nmc_golden.c` — bit-accurate C model of the accelerator
  interface (`nmc.ldw`, `nmc.lda`, `nmc.run`, `nmc.rd`, `nmc_status` CSR @ 0x7C0)
- `nmc_driver.h` — bare-metal driver using `.insn r` to emit the real custom-0
  instructions (opcode 0x0B)
- `test_nmc.c` — 6 directed test cases, all passing on host (gcc, no RTL needed yet)

**Open question for the team:** the official plan (§10.1) and this repo's own
README ownership table both assign the golden model to **C**, not B — but the
ISA-spec doc's "Notes for B" section says the opposite. This needs settling.
Treat the files above as a starting draft, not a finished, owned deliverable.

**Compute-behavior assumptions** (the frozen ISA spec only defines instruction
*encoding*, not the accelerator's math) — need sign-off from A and C:
1. Weights: 1-bit, packed 32/word, bit=1 → +1, bit=0 → −1
2. Activations: int8, one per weight bit
3. `nmc.run`: binary-weight dot product per output → threshold (sign) → 2:1 max-pool
4. `nmc_status` bits: bit0=busy, bit1=done, bit2=error, bit3=ready

### 2.2 Binary-weight LeNet training (`training/`)

- `bwn_lenet.py` — conv1(1→8,3×3)→threshold→2×2 pool→conv2(8→16,3×3)→threshold→
  pool→FC10, matching plan §2.1. Weights binarized via sign() with a
  straight-through estimator for training.
- `train.py` — trains on MNIST. 1-epoch smoke test: **92.38% test accuracy**,
  confirming the architecture and training loop are correct.
- `bwn_lenet.pt` — a full 5-epoch trained checkpoint included in this branch.
- **Next:** export script to produce `weights.hex` + `golden.txt` (D4).

---

## 3. Verification status matrix (my view)

| Item | Status |
|---|---|
| Environment (WSL2, toolchain, riscv-tests cloned) | ✅ done |
| Pipeline stall/deadlock bug | 🔴 found, reported, awaiting A's fix |
| riscv-tests trap/CSR blocker | 🔴 found, needs team decision |
| NMC golden model + driver (draft) | ✅ compiles, self-checks pass — ownership TBD |
| Binary-weight LeNet training | ⏳ in progress, smoke-tested |
| `weights.hex` + `golden.txt` export (D4) | ⏳ not started |
| riscv-tests harness itself (D5) | ⏸️ blocked on §1.2 decision |
| RTL-vs-golden comparison test (D7b) | ⏸️ blocked on golden model ownership + §1.2 |
| SVA, CI | ⏳ not started |
| Independent ½·C·V²·α energy cross-check (D10) | ⏳ not started |

---

## 4. Open questions for the team

1. **A** — can you fix the stall/deadlock bug in §1.1?
2. **A** — which option in §1.2 (real trap support vs. reduced test env) do we go
   with for riscv-tests?
3. **A / C** — can you confirm or correct the compute-behavior assumptions in §2.1?
4. **C** — per the official plan and README table, the golden model is your
   deliverable — do you want to take it over from here, or should I keep building
   on this draft?
