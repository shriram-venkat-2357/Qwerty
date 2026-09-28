# OpenROAD floorplan script for Config S (SRAM macro integration)
# Die: 1850 x 1850 um | Core: 1650 x 1650 um (offset 100 um)

# 1. Read LEF files (Tech, Standard Cells, then Macro)
read_lef /home/vanmathisamikkannu/pdk/volare/sky130/versions/a519523b0d9bc913a6f87a5eed083597ed9e2e93/sky130A/libs.ref/sky130_fd_sc_hd/techlef/sky130_fd_sc_hd__nom.tlef
read_lef /home/vanmathisamikkannu/pdk/volare/sky130/versions/a519523b0d9bc913a6f87a5eed083597ed9e2e93/sky130A/libs.ref/sky130_fd_sc_hd/lef/sky130_fd_sc_hd.lef
read_lef /home/vanmathisamikkannu/src/sky130_sram_macros/sky130_sram_2kbyte_1rw1r_32x512_8/sky130_sram_2kbyte_1rw1r_32x512_8.lef

# 2. Read Liberty
read_liberty /home/vanmathisamikkannu/pdk/volare/sky130/versions/a519523b0d9bc913a6f87a5eed083597ed9e2e93/sky130A/libs.ref/sky130_fd_sc_hd/lib/sky130_fd_sc_hd__tt_025C_1v80.lib

# 3. Read netlist and link
read_verilog build/soc_phys.v
link_design soc_top

# 4. Initialize Floorplan
initialize_floorplan -die_area "0 0 1850 1850" -core_area "100 100 1750 1750" -site unithd

# 5. Place Macros using the OpenDB (odb) TCL API (bypasses mpl/sta command collisions)
# Note: OpenDB uses Database Units (DBU). LEF units are typically 1000 DBU/um.
# 80 um = 80,000 DBU; 600 um = 600,000 DBU.
set db [ord::get_db]
set chip [$db getChip]
set block [$chip getBlock]

set inst1 [$block findInst "u_core.u_imem.u_macro"]
if {$inst1 != "NULL"} {
    $inst1 setPlacementStatus PLACED
    $inst1 setOrigin 80000 80000
    $inst1 setOrient "N"
    puts "Placed IMEM macro at (80, 80)"
} else {
    puts "WARNING: Could not find IMEM macro instance"
}

set inst2 [$block findInst "u_core.u_dmem.u_macro"]
if {$inst2 != "NULL"} {
    $inst2 setPlacementStatus PLACED
    $inst2 setOrigin 80000 600000
    $inst2 setOrient "N"
    puts "Placed DMEM macro at (80, 600)"
} else {
    puts "WARNING: Could not find DMEM macro instance"
}

# 6. Global Placement
set_placement_padding -global -left 2 -right 2
global_placement

# 7. Report
report_design_area
