#!/usr/bin/env bash
set -e

echo "==================================================="
echo "  MediTrack Test Suite Runner (Linux/macOS)"
echo "==================================================="

mkdir -p sim/build
mkdir -p pictures
FAILED=0
TOTAL=0

for tb in tb/unit/tb_*.v; do
    [ -f "$tb" ] || continue
    TOTAL=$((TOTAL + 1))
    tb_name=$(basename "$tb" .v)
    mod_name=${tb_name#tb_}
    echo ""
    echo "Running $tb_name..."

    rtl_file=""
    for dir in reminder configuration timing events peripherals communication; do
        if [ -f "rtl/$dir/${mod_name}.v" ]; then
            rtl_file="rtl/$dir/${mod_name}.v"
            break
        fi
    done

    if iverilog -g2012 -o "sim/build/${tb_name}.vvp" $rtl_file "$tb"; then
        if ! vvp "sim/build/${tb_name}.vvp"; then
            echo "[SIMULATION FAILED] $tb_name"
            FAILED=$((FAILED + 1))
        else
            if [ -f "${tb_name}.vcd" ]; then
                python3 scripts/waveform_screenshot.py "${tb_name}.vcd" "pictures/${tb_name}_waveform.png" "${tb_name} Waveform" || true
                rm -f "${tb_name}.vcd"
            fi
        fi
    else
        echo "[COMPILE ERROR] $tb"
        FAILED=$((FAILED + 1))
    fi
done

echo ""
echo "==================================================="
if [ $FAILED -eq 0 ]; then
    echo "  ALL TESTS PASSED ($TOTAL/$TOTAL)"
    echo "  Screenshots updated in pictures/"
else
    echo "  TESTS FAILED: $FAILED/$TOTAL"
fi
echo "==================================================="
exit $FAILED
