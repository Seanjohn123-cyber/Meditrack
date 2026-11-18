# config.mk -- OpenROAD-flow-scripts starter. INITIAL EXPLORATION ONLY.
# Paths are relative to the repository root; adjust to wherever you run the flow.
export DESIGN_NAME     = medi_soc_top
export PLATFORM        = sky130hd

export VERILOG_FILES   = $(sort $(wildcard ./rtl/*/*.v))
export SDC_FILE        = ./physical_design/constraints/medi_soc.sdc

# Small design: modest utilisation and a fixed die gives an easy first run.
export CORE_UTILIZATION = 30
export PLACE_DENSITY    = 0.60
export TNS_END_PERCENT  = 100
