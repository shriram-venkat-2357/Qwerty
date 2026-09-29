`timescale 1ns/1ps
module tb_nmc_e2e;
    reg clk, rst_n;
    wire [31:0] pc;

    // Instantiate the pipeline with the NMC program
    // Note: Shriram may provide a specific program_e2e.hex later
    rv32_pipeline #(.IMEM_FILE("tb/program_nmc.hex")) u_cpu (
        .clk(clk), .rst_n(rst_n), .pc_out(pc)
    );

    // Golden memory to hold expected results from training/golden.txt
    // Adjust the size [0:63] based on the actual length of golden.txt
    reg [31:0] golden_mem [0:63]; 
    integer i, errs;

    initial begin
        // 1. Load golden results
        $readmemh("training/golden.txt", golden_mem);
        
        // 2. Initialize and reset
        clk = 0;
        rst_n = 0;
        #20;
        rst_n = 1;
        
        errs = 0;
        
        // 3. Run for a sufficient number of cycles for the E2E CNN
        // Shriram will help tune this timeout once the full layer loop is staged
        #100000; 
        
        // 4. Compare RTL results against golden data
        // TODO: Shriram to confirm the exact location of final results 
        // (e.g., DMEM starting at 0x200, or specific register file entries).
        // For now, this is a placeholder checking the first 16 DMEM words.
        for (i = 0; i < 16; i = i + 1) begin
            if (u_cpu.u_dmem.mem[i] !== golden_mem[i]) begin
                errs = errs + 1;
                $display("FAIL at DMEM index %0d: Expected %h, Got %h", 
                         i, golden_mem[i], u_cpu.u_dmem.mem[i]);
            end
        end

        // 5. Report results
        if (errs == 0) 
            $display("ALL E2E CNN TESTS PASSED");
        else 
            $display("%0d E2E CNN checks FAILED", errs);
            
        $finish;
    end

    // Clock generation: 100 MHz (10ns period)
    always #5 clk = ~clk;
endmodule
