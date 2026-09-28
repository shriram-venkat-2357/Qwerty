#!/bin/bash
# C's G2 area-gate run: logic-only area of build C, memories black-boxed.
# Usage: source env.sh && scripts/g2_area_gate.sh
set -e
sed "s|/home/shriram_venkat/pdk|$PDK_ROOT|g; s|/home/[a-z_]*/pdk|$PDK_ROOT|g" \
    scripts/synth_logic_only.ys > build/synth_logic_only_local.ys
yosys -p "script build/synth_logic_only_local.ys; stat -liberty $PDK_LIB" \
    2>&1 | tee reports/g2_stat.txt
