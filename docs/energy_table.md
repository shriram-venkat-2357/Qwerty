# Per-Phase Energy Table — Builds A and C (Week 6, Gate G5)

> **STATUS: PROXY DATA (Week 6 Gate Fallback)**
> Per Risk Register (§12): OpenSTA flow not yet operational. 
> "Cycles" are from RTL simulation. "Energy" values are placeholders. 
> Final numbers pending C's SRAM macro integration and OpenSTA run.

Status: **SCAFFOLD — awaiting B's VCD timestamps and C's OpenSTA numbers.**
Owners: A (schema, netlist, SDC) · B (gate-level SDF VCD + phase log) · C (OpenSTA read_power_activity).

Inputs:
- Netlist: `build/soc_top_synth.v` (Week-6 frozen commit)
- SDC: `scripts/soc_top.sdc` (false paths: async reset; labelled FF-memory-read exclusions)
- Activity: B's gate-level VCD + `build/power_phases.log` (phase start/end cycles)
- Workload: one representative CNN layer; if D4 weights are still missing, the
  `sim_nmc` loop labelled **"Synthetic Layer"** (state this wherever the table is quoted)

Reporting rules (plan §9.2, §4.2):
1. Kernel-only (Conv+Threshold+Pool) and end-to-end (incl. loads/readback) are
   reported SEPARATELY. Never present kernel-only as end-to-end.
2. Leakage reported separately from dynamic on every row.
3. Per-instance split: SoC total AND `u_nmc_unit` alone.
4. Activation marshalling energy is charged to BOTH sides of every A-vs-C comparison.

## Build A (scalar RV32IM core, no accelerator)

| Phase | Cycles | Dynamic (pJ) | Leakage (pJ) | Total (pJ) | Scope |
|---|---|---|---|---|---|
| Weight load   | TBD | TBD | TBD | TBD | SoC |
| Activation load | TBD | TBD | TBD | TBD | SoC |
| Conv (MAC)    | TBD | TBD | TBD | TBD | SoC |
| Threshold     | TBD | TBD | TBD | TBD | SoC |
| Pool          | TBD | TBD | TBD | TBD | SoC |
| Readback      | TBD | TBD | TBD | TBD | SoC |
| **End-to-end (1 inference)** | TBD | TBD | TBD | TBD | SoC |
| Kernel-only (Conv+Thresh+Pool) | TBD | TBD | TBD | TBD | SoC |

## Build C (core + nmc_unit, -DNMC)

| Phase | Cycles | Dynamic (pJ) | Leakage (pJ) | Total (pJ) | SoC | u_nmc_unit |
|---|---|---|---|---|---|---|
| Weight load   | TBD | TBD | TBD | TBD | TBD | TBD |
| Activation load | TBD | TBD | TBD | TBD | TBD | TBD |
| Conv (MAC)    | TBD | TBD | TBD | TBD | TBD | TBD |
| Threshold     | TBD | TBD | TBD | TBD | TBD | TBD |
| Pool          | TBD | TBD | TBD | TBD | TBD | TBD |
| Readback      | TBD | TBD | TBD | TBD | TBD | TBD |
| **End-to-end (1 inference)** | TBD | TBD | TBD | TBD | TBD | TBD |
| Kernel-only (Conv+Thresh+Pool) | TBD | TBD | TBD | TBD | TBD | TBD |

## Cross-checks (G5 "internally consistent")
- [ ] Sum of per-phase totals equals end-to-end total (±1%)
- [ ] Dynamic + leakage equals total on every row
- [ ] Build C end-to-end < Build A end-to-end, else report honestly and investigate
- [ ] B's independent ½·C·V²·α estimate (D10, Week 7) within 2× of C's OpenSTA dynamic number

## Fallback (risk register, G5)
If OpenSTA yields no usable number by end of Week 6, publish labelled proxies:
cycle counts per phase (RTL sim), toggle counts per phase, SRAM bit-toggle energy
estimate — labelled "Week 6 Energy Proxies (full flow pending SRAM macro integration)".

## Known caveats (state with every quotation of this table)
- FF-mapped IMEM/DMEM inflate memory-phase energy; SRAM macro substitution
  (§2.1, C, Week 7) changes these numbers. Re-run and version the table afterwards.
- FF-mapped netlist timing is artifact-bound (~279 kHz); energy is activity-driven
  and remains usable, but state the clock assumption used for leakage integration.
