# medi_soc.sdc -- INITIAL EXPLORATION ONLY (Person 5). Not signed-off timing.
# 100 MHz placeholder clock; tighten/relax once synthesis results are known.
create_clock -name clk -period 10.0 [get_ports clk]
set_clock_uncertainty 0.25 [get_clocks clk]

# Every non-clock input arrives 2 ns after the clock edge (placeholder).
set_input_delay  2.0 -clock clk [remove_from_collection [all_inputs] [get_ports clk]]
# Every output must be valid 2 ns before the next edge (placeholder).
set_output_delay 2.0 -clock clk [all_outputs]

# rst_n is asynchronous; do not time it against clk.
set_false_path -from [get_ports rst_n]
