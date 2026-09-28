# OpenSTA Baseline Run - Build C

# 1. Read Liberty and Netlist
read_liberty $::env(PDK_LIB)
read_verilog build/soc_top_synth.v
link_design soc_top

# 2. Read Constraints
read_sdc scripts/soc_top.sdc

# 3. Report Timing
report_checks -path_delay max -fields {slew cap input net fanout} -digits 4 > build/timing_report_40ns.txt

puts "STA Complete. Check build/timing_report_40ns.txt"
