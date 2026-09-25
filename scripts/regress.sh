#!/usr/bin/env bash
cd "$(dirname "$0")/.."
fail=0
for t in smoke_nop:500 smoke_b2b:500 lui:500 auipc:500 jal_jalr:500 ldst:1000 branches:2000 loaduse:2000 mul:2000 div:2000; do
  name=${t%%:*}; tmo=${t##*:}
  res=$(scripts/run_prog.sh tests/$name.S $tmo 2>&1 | grep -E "^(PASS|FAIL|TIMEOUT)" | head -1)
  printf "%-12s %s\n" "$name" "${res:-NO RESULT}"
  case "$res" in PASS*) ;; *) fail=1;; esac
done
iverilog -g2012 -o build/tb_trap.vvp tb/tb_trap.v $(find rtl -name '*.v') 2>&1
trap_res=$(vvp build/tb_trap.vvp | grep -E "ALL TRAP TESTS PASSED|FAIL" | head -1)
printf "%-12s %s\n" "trap" "${trap_res:-NO RESULT}"
case "$trap_res" in *PASSED*) ;; *) fail=1;; esac
[ $fail -eq 0 ] && echo "REGRESSION: ALL PASS" || echo "REGRESSION: FAILURES"
exit $fail
