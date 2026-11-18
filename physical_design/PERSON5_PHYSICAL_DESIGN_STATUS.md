# Person 5 Physical Design Status

## Preparation Completed
- Created initial OpenROAD configuration.
- Created initial SDC timing constraints.
- Prepared the Sky130HD platform configuration.
- Completed standalone Yosys synthesis for the three Person 5 peripheral modules.

## Current Limitations
- The full SoC top-level module (medi_soc_top.v) is not yet available.
- Full SoC synthesis has not been performed.
- OpenROAD floorplanning, placement, clock-tree synthesis, routing, and timing signoff have not been performed.

## Next Steps
- Integrate all team RTL modules.
- Confirm the top-level module and its interfaces.
- Run full SoC synthesis.
- Validate timing constraints against the integrated design.
- Begin the OpenROAD physical-design flow.
