# 0004 — G2 area reconciliation (3.36M vs 1.75M vs 0.98M µm²)
Status: accepted (C, Wk7). Numbers 0002 (nmc.cfg) and 0003 (G2 final call) reserved per A's register.
- 3,356,689 µm² (C g2, Wk6): logic + IMEM/DMEM FF-mapped at post-resize sizes.
- 1,746,603 µm² (A Wk6 build-C): logic + FF-mapped memories at older sizes.
- 977,838 µm² (Wk7, reports/g2_stat.txt): true logic-only, memories black-boxed.
- Delta ≈2.38M µm² is FF-mapped memory, not logic. Reproduce: scripts/g2_area_gate.sh

## Flow roles (post-28582e4 canonicalization)
- scripts/synth_clean.ys (A): generic-gate audit netlist (build/soc_gate.v); no liberty mapping.
- scripts/g2_area_gate.sh (C): logic-only liberty area gate (synth_logic_only.ys + stat -liberty,
  memories black-boxed). Authoritative for G2 and die-budget numbers.

## Correction (Wk7): parse_area.py extraction bug
parse_area.py emitted "Total Chip Area: 0.00 um^2", making its PASSED line vacuous.
Authoritative array area: reports/g2_array_probe_wk7.txt (scripts/area_probe.ys + stat -liberty)
= 180,973.568 um^2 vs cap 180,973.73 um^2 -> verdict: PASSED (re-probe reproduces D3 cap within 0.162 um^2; no array growth post-freeze).
parse_area.py is deprecated for gate decisions; kept only as cell-histogram utility.
