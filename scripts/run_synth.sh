#!/usr/bin/env bash
# Usage: scripts/run_synth.sh [clean|logic_only]
set -euo pipefail
cd "$(git rev-parse --show-toplevel)"
source ./env.sh
case "${1:-clean}" in
  clean)      sed "s|@PDK_LIB@|$PDK_LIB|g" scripts/synth_clean.ys.in      > build/synth_clean.ys;      yosys -s build/synth_clean.ys      > build/synth_clean.log 2>&1 ;;
  logic_only) sed "s|@PDK_LIB@|$PDK_LIB|g" scripts/synth_logic_only.ys.in > build/synth_logic_only.ys; yosys -s build/synth_logic_only.ys > build/synth_logic_only.log 2>&1 ;;
esac
