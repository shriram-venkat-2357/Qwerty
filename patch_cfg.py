import re

# --- 1. Patch cim_sequencer.v ---
with open('rtl/accel/cim_sequencer.v', 'r') as f:
    seq = f.read()

# Add default assignments in the reset block
seq = seq.replace(
    'w3 <= 0; asm_reg <= 0; res <= 0; done_r <= 0; error_r <= 0;',
    'w3 <= 0; asm_reg <= 0; res <= 0; done_r <= 0; error_r <= 0;\n            we_thr <= 0; thr_addr <= 0; thr_data <= 0;'
)

# Add default assignments in the sequential block (pulses we_thr for 1 cycle)
seq = seq.replace(
    'act_valid <= 1\'b0;',
    'act_valid <= 1\'b0;\n            we_thr <= 1\'b0;'
)

# Add the decode case for funct3 = 100
old_case = """3'b010: begin
                        if (fcnt < 4) begin error_r <= 1'b1; done_r <= 1'b1; end
                        else begin state <= RUN; w3 <= 0; end
                    end"""
new_case = old_case + """
                    3'b100: begin
                        we_thr <= 1'b1;
                        thr_addr <= rs1[$clog2(COLS)-1:0];
                        thr_data <= rs2;
                    end"""
seq = seq.replace(old_case, new_case)

with open('rtl/accel/cim_sequencer.v', 'w') as f:
    f.write(seq)

# --- 2. Patch tb_nmc_instr.v ---
with open('tb/tb_nmc_instr.v', 'r') as f:
    tb = f.read()

# Add a functional test for nmc.cfg before the final summary
test_code = """
    // --- Test nmc.cfg (Decision 0002) ---
    // Set threshold for column 0 to 128 (0x80)
    issue_custom(4, 0, 32'h00000080); 
    wait_done();
    
    // Run convolution (weights=1, acts=1 -> acc=256)
    issue_custom(2, 0, 0); 
    wait_done();
    
    // Read result
    issue_custom(3, 0, 0); 
    wait_done();
    
    // 256 >= 128 is true, so bit 0 of result should be 1.
    if (rd !== 32'h1) begin
        $display("FAIL nmc.cfg: expected rd=1 (256>=128), got %h", rd);
        checks_failed = checks_failed + 1;
    end else begin
        $display("PASS nmc.cfg (threshold=128, acc=256)");
    end
"""

# Insert right before the final summary display
tb = tb.replace('if (checks_failed == 0)', test_code + '\n    if (checks_failed == 0)')

with open('tb/tb_nmc_instr.v', 'w') as f:
    f.write(tb)

print("RTL and Testbench patched successfully.")
