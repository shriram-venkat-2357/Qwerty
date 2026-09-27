# Baseline SDC for soc_top (Build C)
# Target: 25 MHz (40 ns period)

# 1. Clock definition
create_clock -name clk -period 40.0 [get_ports clk]
set_ideal_network [get_ports clk]

# 2. Reset is asynchronous, but we constrain its arrival to be safe
set_input_delay -clock clk -max 5.0 [get_ports rst_n]
set_input_delay -clock clk -min 2.0 [get_ports rst_n]

# 3. Output delays (conservative estimate for external routing)
set_output_delay -clock clk -max 5.0 [get_ports pc_out]
set_output_delay -clock clk -min 2.0 [get_ports pc_out]

# Exclude async reset from synchronous data timing
set_false_path -from [get_ports rst_n]

# --- LABELLED EXCLUSION (Week 6 STA): FF-mapped IMEM/DMEM read muxes.
# Inferred-memory read is a modelling artifact; the deliverable memory is
# the Sky130 SRAM macro (plan 2.1). Excluded ONLY to expose the logic
# critical path. Both numbers are reported side by side; neither is hidden.
set_false_path -through [get_nets *mem_rdata*]
set_false_path -through [get_nets *instr*]
set_false_path -through [get_nets *b_rdata*]

# --- LABELLED EXCLUSION (Week 6 STA): Strip FF-memory address decoder load.
# In a real chip, the SRAM macro has its own address buffer. The FF-mapped
# netlist forces the logic (forwarding unit) to drive the 8000-load memory
# decoder directly, adding ~220ns of artificial slew. We override the load
# to expose the true logic critical path.
set_load 0.05 [get_nets u_core.mem_alu_result*]
set_load 0.05 [get_nets u_core.ex_alu_result*]
set_load 0.05 [get_nets u_core.seq_b_addr*]
set_load 0.05 [get_nets u_core.imem_rdata*]
set_load 0.05 [get_nets u_core.mem_wdata*]
set_load 0.05 [get_nets u_core.mem_addr*]

# Corrected patterns: flattened net names are escaped (\-prefixed),
# so every pattern needs a leading * to match. Same labelled class:
# FF-memory interface loads replaced by SRAM macro buffering (plan 2.1).
set_load 0.05 [get_nets *mem_alu_result*]
set_load 0.05 [get_nets *ex_alu_result*]
set_load 0.05 [get_nets *seq_b_addr*]
set_load 0.05 [get_nets *mem_wdata*]
set_load 0.05 [get_nets *mem_addr*]
set_load 0.05 [get_nets *instr*]

# Override the TOTAL load seen by the registers driving FF-memory address
# buses (set_load on the driver PIN replaces the 8272-fanout pin capacitance).
set_load 0.05 [get_pins -of_objects [get_nets *mem_alu_result*] -filter {direction == out}]
set_load 0.05 [get_pins -of_objects [get_nets *seq_b_addr*]      -filter {direction == out}]
