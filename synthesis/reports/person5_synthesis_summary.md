
# Person 5 – Yosys Synthesis Summary

## Tool
- Yosys 0.70+385 (OSS CAD Suite)
- Synthesis type: Standalone module synthesis

## Results

| Module | Configuration | Total Mapped Cells | Sequential Cells | Yosys Problems |
|---|---|---:|---:|---:|
| Alert Controller | Steady (BLINK_EN=0) | 0 | 0 | 0 |
| Alert Controller | Blinking (BLINK_EN=1) | 97 | 17 | 0 |
| Compartment Controller | 15 Slots | 169 | 23 | 0 |
| Display Controller | Default | 51 | 0 | 0 |

## Verification
- All three Person 5 modules completed standalone Yosys synthesis.
- Compartment controller simulation passed with 15 compartments.
- All final Yosys design checks reported zero problems.

## Saved Synthesis Logs
- alert_controller_blinking_yosys.log
- compartment_controller.log
- display_controller_yosys.log

## Limitation
These are standalone synthesis results, not full SoC synthesis or physical-design signoff.

Full SoC synthesis requires the remaining team modules and the top-level module.
