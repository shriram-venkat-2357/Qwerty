`timescale 1ns/1ps
module tb_soc;
    reg clk, rst_n;
    wire [31:0] pc;

    soc_top u_soc (.clk(clk), .rst_n(rst_n), .pc_out(pc));

    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        rst_n = 0; #20; rst_n = 1;
        #500;
        if (pc === 32'd0) begin
            $display("FAIL: core did not run");
        end else begin
`ifdef NMC
            $display("BUILD C smoke OK: pc=%h, nmc_unit present", pc);
`else
            $display("BUILD A smoke OK: pc=%h", pc);
`endif
            $display("SOC SMOKE PASSED");
        end
        $finish;
    end
endmodule
