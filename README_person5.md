# MediTrack -- Person 5 deliverables
Copy these folders into the shared MediTrack repository (paths already match the team layout).
Run from the repo root:
    bash scripts/run_peripheral_tests.sh     # unit tests (needs iverilog)
    bash scripts/run_synthesis.sh            # synthesis check (needs yosys)
View waveforms: gtkwave sim/build/tb_compartment_controller.vcd
