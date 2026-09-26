`timescale 1ns/1ps
module tb_soc_gate;
    reg clk, rst_n;
    wire [31:0] pc;

    // Instantiate the gate-level netlist
    soc_top u_soc (.clk(clk), .rst_n(rst_n), .pc_out(pc));

    // Clock generation: 100 MHz (10ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // VCD Dumping
    initial begin
        $dumpfile("build/soc_gate.vcd");
        $dumpvars(0, tb_soc_gate); // Dump all hierarchy levels
    end

    integer errs;
    initial begin
        $display("=== PHASE 1: RESET ===");
        errs = 0;
        rst_n = 0; 
        #20; 
        rst_n = 1;
        
        $display("=== PHASE 2: EXECUTION ===");
        #500; // Run for 500 time units (50 cycles)
        
        $display("=== PHASE 3: CHECK ===");
        if (pc === 32'd0) begin
            errs = errs + 1;
            $display("FAIL: core did not run (pc=0)");
        end else begin
            $display("BUILD GATE SMOKE OK: pc=%h", pc);
        end
        
        if (errs == 0) $display("GATE SMOKE PASSED");
        else $display("GATE SMOKE FAILED");
        
        $display("=== PHASE 4: FINISH ===");
        $finish;
    end
endmodule
