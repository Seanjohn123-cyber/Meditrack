# Implementation plan (Person 5)

## Tools
Icarus Verilog (`iverilog`, `vvp`), GTKWave, Yosys, Git. Optional later: OpenROAD-flow-scripts.

## Build order
1. D1  Freeze encodings and lock policy in docs/module_interfaces.md.
2. D2  RTL: alert_controller -> display_controller -> compartment_controller. Commit after each.
3. D3  Unit testbenches; `bash scripts/run_peripheral_tests.sh` must print ALL PERIPHERAL TESTS PASSED.
4. D3-5 Integrate with medi_soc_top; check peripherals follow reminder_active/active_slot in system waveforms.
5. D6  Synthesis: `bash scripts/run_synthesis.sh --all`; record warnings in synthesis/reports/warnings_summary.txt and report to module owners.
6. D6  Physical-design exploration: review medi_soc.sdc and openroad/config.mk; run flow only if time allows (exploration, not sign-off).
7. D7  Demo peripherals, state known limitations, explain the end-to-end event path.

## Synthesis steps
`yosys -s synthesis/yosys/synth.ys` reads every RTL file, runs proc/check/opt/synth/stat. Look for: inferred latches, multiple drivers, unsynthesizable constructs (#delays, initial blocks). Store logs in synthesis/reports/.

## Known limitations
Prototype only; no clinical validation. Unlocking and acknowledgement do not prove ingestion. The display shows idle/active and slot only. Relock uses a timer because the MVP has no door sensor.

## Git
Branch `feature/person5-peripherals`; commit RTL + testbench + docs together; pull request reviewed by another member; nothing untested into main.
