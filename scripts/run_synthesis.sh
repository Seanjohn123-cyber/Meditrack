#!/bin/bash
# Synthesis helper (Person 5). Run from the repository root.
#   ./scripts/run_synthesis.sh            -> each peripheral module on its own
#   ./scripts/run_synthesis.sh --all      -> every rtl/**/*.v module on its own,
#                                            then the full SoC via synth.ys
# Reports go to synthesis/reports/. Warnings are collected in warnings_summary.txt
# so they can be recorded and sent to the module owner.
YOSYS=$(command -v yosys || command -v yowasp-yosys)
[ -z "$YOSYS" ] && { echo "yosys not found (apt install yosys, or pip install yowasp-yosys)"; exit 1; }
mkdir -p synthesis/reports
SUMMARY=synthesis/reports/warnings_summary.txt
: > "$SUMMARY"

synth_one () {            # $1 = file, $2 = top module
    local log=synthesis/reports/$2.log
    "$YOSYS" -q -l "$log" -p "read_verilog -sv $1; hierarchy -check -top $2; proc; check; opt; synth -top $2; check; stat" >/dev/null 2>&1
    local rc=$?
    local bad=$(grep -E "Latch inferred|Warning:|ERROR|conflicting drivers|multiple drivers" "$log" | sort -u)
    echo "== $2 (exit $rc) ==" >> "$SUMMARY"
    if [ -n "$bad" ]; then echo "$bad" >> "$SUMMARY"; else echo "no warnings" >> "$SUMMARY"; fi
    echo "$2: exit $rc, $( [ -n "$bad" ] && echo 'WARNINGS - see summary' || echo 'clean')"
}

if [ "$1" == "--all" ]; then
    for f in $(find rtl -name '*.v' ! -path '*/top/*'); do synth_one "$f" "$(basename "$f" .v)"; done
    [ -f rtl/top/medi_soc_top.v ] && { "$YOSYS" -l synthesis/reports/medi_soc_top.log -s synthesis/yosys/synth.ys >/dev/null 2>&1; echo "medi_soc_top: exit $?"; }
else
    for m in alert_controller display_controller compartment_controller; do synth_one rtl/peripherals/$m.v $m; done
fi
echo "Summary: $SUMMARY"
