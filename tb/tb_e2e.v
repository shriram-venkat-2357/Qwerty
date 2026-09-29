`timescale 1ns/1ps
module tb_e2e;
    reg clk, rst_n;
    wire [31:0] pc;
    
    soc_top #(.IMEM_FILE("tb/program_e2e.hex")) u_soc (
        .clk(clk), .rst_n(rst_n), .pc_out(pc)
    );
    
    // Dump VCD so you can visually verify the result in GTKWave tomorrow if needed
    initial begin
        $dumpfile("build/e2e.vcd");
        $dumpvars(0, tb_e2e);
    end
    
    initial clk = 0;
    always #5 clk = ~clk;
    
    integer c;
    initial begin
        c = 0; rst_n = 0;
        #20; rst_n = 1;
        
        while (c < 200000) begin
            @(posedge clk);
            c = c + 1;
            
            // The 'halt' loop in our assembly program is at address 0x58.
            // If the PC reaches here, the accelerator finished and the CSR poll succeeded.
            if (pc == 32'h00000058) begin
                $display("PASS: End-to-End Harness Green. Reached halt loop.");
                $finish;
            end
        end
        $display("FAIL: Timeout. PC did not reach 0x58 (hung in poll loop).");
        $finish;
    end
endmodule
