#!/usr/bin/env bash
# Um unico comando: lint + testbenches (Verilator). Uso: ./scripts/run_tests.sh
set -euo pipefail
cd "$(dirname "$0")/.."
RTL=(rtl/minisoc_aes/minisoc_aes_gf_pkg.sv $(ls rtl/minisoc_aes/*.sv | grep -v gf_pkg))
echo "### LINT"
verilator --lint-only -Wall -Wno-DECLFILENAME -Wno-UNUSEDSIGNAL --top-module minisoc_aes_dp "${RTL[@]}"
echo "lint OK"
for TB in tb_aes_round_transforms tb_aes_key_exp tb_aes_dp; do
  echo "### SIM $TB"
  rm -rf obj_$TB
  verilator --binary --timing -Wno-fatal -Wno-lint -Wno-style -Wno-TIMESCALEMOD -Itb --Mdir obj_$TB --top-module $TB \
      "${RTL[@]}" tb/$TB.sv -o sim_$TB > obj_$TB.log 2>&1 || { cat obj_$TB.log; exit 1; }
  ./obj_$TB/sim_$TB | tee sim_$TB.log
  grep -q "^PASS" sim_$TB.log
done
echo "### TUDO PASS"
