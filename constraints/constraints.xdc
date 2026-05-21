# Clock constraint — 13ns period (76.9MHz)
create_clock -period 13.0 -name clk [get_ports clk]

# IO delay constraints
set_input_delay  -clock clk 2.0 [get_ports reset]
set_input_delay  -clock clk 2.0 [get_ports start]
set_output_delay -clock clk 2.0 [get_ports done]

# Suppress IO standard warnings (no physical board target)
set_property SEVERITY {Warning} [get_drc_checks NSTD-1]
set_property SEVERITY {Warning} [get_drc_checks UCIO-1]
