read_liberty $::env(PDK_LIB)
read_verilog build/soc_top_synth.v
link_design soc_top
read_sdc scripts/soc_top.sdc
write_sdf libs/soc_top_preRoute.sdf
puts "SDF generated: libs/soc_top_preRoute.sdf (pre-route, zero wire delay)"
