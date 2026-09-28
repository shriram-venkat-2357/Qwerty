read_liberty $::env(PDK_LIB)
read_verilog build/soc_top_logic_only.v
link_design soc_top

# Read baseline SDC (clock and reset definitions)
read_sdc scripts/soc_top.sdc

# Only exclude the async reset to avoid false violations on reset logic
set_false_path -from [get_ports rst_n]

# Report the true logic critical path
report_checks -path_delay max -fields {slew cap input net fanout} -digits 4 > build/timing_logic_only.txt
puts "STA Complete."
