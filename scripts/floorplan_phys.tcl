# OpenROAD floorplan script for Config S (SRAM macro integration)
# Die: 1850 x 1850 um | Core: 1650 x 1650 um (offset 100 um)

# 1. Initialize Floorplan
initialize_floorplan -die_area "0 0 1850 1850" -core_area "100 100 1750 1750" -site unithd

# 2. Read LEF files
# Tech LEF (nominal corner)
read_lef /home/vanmathisamikkannu/pdk/volare/sky130/versions/a519523b0d9bc913a6f87a5eed083597ed9e2e93/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
# Macro LEF
read_lef /home/vanmathisamikkannu/src/sky130_sram_macros/sky130_sram_2kbyte_1rw1r_32x512_8/sky130_sram_2kbyte_1rw1r_32x512_8.lef

# 3. Read Liberty (for timing-driven placement)
read_liberty /home/vanmathisamikkannu/pdk/volare/sky130/versions/a519523b0d9bc913a6f87a5eed083597ed9e2e93/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# 4. Read the synthesized netlist
read_verilog build/soc_phys.v
link_design soc_top

# 5. Place Macros explicitly
# IMEM macro instance (hierarchical path from imem_macro_ss.v)
place_macro imem/u_macro -x 80 -y 80 -orient N
# DMEM macro instance (hierarchical path from dmem_macro_ss.v)
place_macro dmem/u_macro -x 80 -y 600 -orient N

# 6. Global Placement
# Set placement padding to avoid congestion near macros
set_placement_padding -global -left 2 -right 2
global_placement

# 7. Report initial placement area
report_design_area
