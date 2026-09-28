# 0004 — G2 area reconciliation (3.36M vs 1.75M vs 0.98M µm²)
Status: accepted (C, Wk7). Numbers 0002 (nmc.cfg) and 0003 (G2 final call) reserved per A's register.
- 3,356,689 µm² (C g2, Wk6): logic + IMEM/DMEM FF-mapped at post-resize sizes.
- 1,746,603 µm² (A Wk6 build-C): logic + FF-mapped memories at older sizes.
- 977,838 µm² (Wk7, reports/g2_stat.txt): true logic-only, memories black-boxed.
- Delta ≈2.38M µm² is FF-mapped memory, not logic. Reproduce: scripts/g2_area_gate.sh
