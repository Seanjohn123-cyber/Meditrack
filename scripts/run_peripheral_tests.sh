#!/bin/bash
# Run Person 5 unit tests with Icarus Verilog. Run from the repository root.
set -u
mkdir -p sim/build
fail=0
for m in alert_controller display_controller compartment_controller; do
    echo "=== $m ==="
    iverilog -g2005 -Wall -o sim/build/tb_$m.vvp rtl/peripherals/$m.v tb/unit/tb_$m.v || { fail=1; continue; }
    out=$(vvp sim/build/tb_$m.vvp)
    echo "$out"
    echo "$out" | grep -q "^PASS" || fail=1
done
[ $fail -eq 0 ] && echo "ALL PERIPHERAL TESTS PASSED" || echo "SOME TESTS FAILED"
exit $fail
