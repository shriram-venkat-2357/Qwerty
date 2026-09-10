# OpenROAD Tcl script for counter layout

set PDK_ROOT "$env(HOME)/pdk"
set VERSION "a519523b0d9bc913a6f87a5eed083597ed9e2e93"

# 1. Read Technology LEF first (defines the 'unithd' site and metal layers)
read_lef $PDK_ROOT/volare/sky130/versions/$VERSION/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef

# 2. Read Standard Cell LEF and Liberty files
read_lef $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
read_liberty $PDK_ROOT/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# 3. Read the synthesized netlist
read_verilog build/cpu_synth.v
link_design rv32_pipeline

# 4. Floorplan
initialize_floorplan -utilization 5 -aspect_ratio 1.0 -core_space 20 -site unithd

# 5. Generate routing tracks from the tech LEF's pitch/offset data
make_tracks

# 6. Place I/O pins
place_pins -hor_layers met3 -ver_layers met2

# 7. Placement
insert_tiecells sky130_fd_sc_hd__conb_1/HI
insert_tiecells sky130_fd_sc_hd__conb_1/LO
global_placement
detailed_placement

# 8. Clock tree synthesis
#    NOTE: change "clk" below if your counter's clock port has a different
#    name (check with: grep -i input build/counter_synth.v)
create_clock -name clk -period 10 [get_ports clk]
set_wire_rc -clock -layer met3
clock_tree_synthesis -root_buf sky130_fd_sc_hd__clkbuf_4 -buf_list sky130_fd_sc_hd__clkbuf_4

# 8b. Re-legalize placement: CTS just added new buffer cells that are not
#     yet snapped to legal sites/rows. Without this, the router can't find
#     a valid access point on their pins (DRT-0073).
detailed_placement

# 9. Routing
global_route
detailed_route

# 10. Outputs
#     NOTE: OpenROAD has no native write_gds command - GDS is generated
#     afterward using Magic, which reads this DEF + the sky130 LEF/tech file.
#     Also: detailed_route already prints "Number of violations = 0" above,
#     so a separate print_violation step isn't needed.
write_def build/cpu.def

#exit
