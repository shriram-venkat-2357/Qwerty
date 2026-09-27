`timescale 1ns/1ps
module tb_pool_reduce;
    localparam COLS = 2, W = 8;

    reg clk, rst_n, valid, first, last;
    reg [COLS*W-1:0] din;
    wire [COLS*W-1:0] dout;
    wire dout_valid;

    nmc_pool_reduce #(.COLS(COLS), .W(W)) u (
        .clk(clk), .rst_n(rst_n), .valid(valid), .first(first), .last(last),
        .din(din), .dout(dout), .dout_valid(dout_valid)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer errs;
    initial begin
        errs = 0;
        rst_n = 0; valid = 0; first = 0; last = 0; din = 0;
        #20; rst_n = 1;

        // Window 1: col0: 3,7,2,5 -> 7 ; col1: -4,-1,-9,-2 -> -1
        valid = 1; first = 1; last = 0; din = {-8'sd4, 8'sd3}; @(posedge clk); #1;
        first = 0;                      din = {-8'sd1, 8'sd7}; @(posedge clk); #1;
                                        din = {-8'sd9, 8'sd2}; @(posedge clk); #1;
                          last = 1;     din = {-8'sd2, 8'sd5}; @(posedge clk); #1;
        if (dout_valid !== 1'b1) begin errs=errs+1; $display("FAIL dout_valid"); end
        if (dout !== {-8'sd1, 8'sd7}) begin errs=errs+1;
            $display("FAIL window max: dout=%h", dout); end

        // Idle: dout_valid drops, dout holds
        valid = 0; first = 0; last = 0; @(posedge clk); #1;
        if (dout_valid !== 1'b0) begin errs=errs+1; $display("FAIL valid drop"); end
        if (dout !== {-8'sd1, 8'sd7}) begin errs=errs+1; $display("FAIL hold"); end

        // Degenerate window (first && last): pass-through
        valid = 1; first = 1; last = 1; din = {-8'sd6, 8'sd4}; @(posedge clk); #1;
        if (dout !== {-8'sd6, 8'sd4}) begin errs=errs+1;
            $display("FAIL single-phase: dout=%h", dout); end

        if (errs == 0) $display("ALL POOL TESTS PASSED");
        else $display("%0d pool checks FAILED", errs);
        $finish;
    end
endmodule
