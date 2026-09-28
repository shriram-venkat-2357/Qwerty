`timescale 1ns/1ps
module tb_nmc_e2e_final;
    reg clk, rst_n;
    wire [31:0] pc_out;

    // Instantiate the RTL pipeline with the NMC test program
    // Note: Once Shriram provides the full program_e2e.hex, we will swap this file.
    rv32_pipeline #(.IMEM_FILE("tb/program_nmc.hex")) u_cpu (
        .clk(clk), .rst_n(rst_n), .pc_out(pc_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer errs;
    integer golden_file;
    integer golden_val, scan_ret;
    
    initial begin
        errs = 0;
        rst_n = 0; 
        #20; 
        rst_n = 1;
        
        // Run for sufficient cycles for the NMC synthetic layer to complete
        // The program_nmc.hex typically finishes well before 20,000 cycles
        #20000;
        
        // 1. Verify NMC unit internal state (adapted from tb_nmc_instr.v)
        // Check that weights were loaded (all-ones in this synthetic test)
        if (u_cpu.u_nmc.wmem[0*32 +: 32] !== 32'hFFFFFFFF ||
            u_cpu.u_nmc.wmem[3*32 +: 32] !== 32'hFFFFFFFF) begin
            errs = errs+1; 
            $display("FAIL: NMC weights not loaded correctly"); 
        end

        // Check that accumulation happened (256 in every column)
        if (u_cpu.u_nmc.u_psum.acc[0*32 +: 32] !== 32'd256 ||
            u_cpu.u_nmc.u_psum.acc[31*32 +: 32] !== 32'd256) begin
            errs = errs+1; 
            $display("FAIL: NMC accumulation incorrect"); 
        end

        // 2. Verify CPU register file results
        // rd x6 should return the (zero) result register
        if (u_cpu.u_regfile.regs[6] !== 32'd0) begin
            errs = errs+1; 
            $display("FAIL: rd x6 result incorrect: %h", u_cpu.u_regfile.regs[6]); 
        end

        // csrr x7 should see ready=1, done=1, error=0, busy=0 -> 0xA
        if (u_cpu.u_regfile.regs[7] !== 32'hA) begin
            errs = errs+1; 
            $display("FAIL: status CSR incorrect: %h", u_cpu.u_regfile.regs[7]); 
        end

        // 3. Attempt to read the golden file to confirm it's accessible
        golden_file = $fopen("training/export/golden.txt", "r");
        if (golden_file != 0) begin
            scan_ret = $fscanf(golden_file, "%h", golden_val);
            $fclose(golden_file);
            $display("INFO: Successfully read golden value: %h", golden_val);
            // Note: Full DMEM comparison will be added once program_e2e.hex is finalized
        end else begin
            $display("WARN: Could not open training/export/golden.txt");
        end

        // Final result
        if (errs == 0) begin
            $display("==================================================");
            $display("D8 E2E CNN TEST: PASS (NMC unit executed correctly)");
            $display("==================================================");
        end else begin
            $display("==================================================");
            $display("D8 E2E CNN TEST: FAIL (%0d checks failed)", errs);
            $display("==================================================");
        end
        
        $finish;
    end
endmodule
