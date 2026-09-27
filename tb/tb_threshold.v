`timescale 1ns/1ps
module tb_threshold;
    localparam COLS = 2, ACC_W = 16, THR_W = 16;

    reg clk, rst_n, we, valid;
    reg [$clog2(COLS)-1:0] waddr;
    reg [THR_W-1:0] wdata;
    reg [COLS*ACC_W-1:0] acc_in;
    wire [COLS-1:0] act_out;

    nmc_threshold #(.COLS(COLS), .ACC_W(ACC_W), .THR_W(THR_W)) u (
        .clk(clk), .rst_n(rst_n), .we(we), .waddr(waddr), .wdata(wdata),
        .valid(valid), .acc_in(acc_in), .act_out(act_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer errs;
    initial begin
        errs = 0;
        rst_n = 0; we = 0; valid = 0; waddr = 0; wdata = 0; acc_in = 0;
        #20; rst_n = 1;

        // Load thr[0] = -5, thr[1] = 10
        we = 1; waddr = 0; wdata = 16'hFFFB; @(posedge clk); #1;
        waddr = 1; wdata = 16'd10;           @(posedge clk); #1;
        we = 0;
        if (u.thr[0] !== 16'hFFFB || u.thr[1] !== 16'd10) begin
            errs = errs+1; $display("FAIL thr load"); end

        // acc = {col1=10, col0=-5}: both equal thresholds -> 2'b11
        valid = 1; acc_in = {16'sd10, -16'sd5}; @(posedge clk); #1;
        if (act_out !== 2'b11) begin
            errs = errs+1; $display("FAIL boundary: act=%b", act_out); end

        // acc = {col1=10, col0=-6}: col0 below -> 2'b10
        acc_in = {16'sd10, -16'sd6}; @(posedge clk); #1;
        if (act_out !== 2'b10) begin
            errs = errs+1; $display("FAIL below-thr: act=%b", act_out); end

        // valid=0 -> hold
        valid = 0; acc_in = 0; @(posedge clk); #1;
        if (act_out !== 2'b10) begin
            errs = errs+1; $display("FAIL hold: act=%b", act_out); end

        if (errs == 0) $display("ALL THRESHOLD TESTS PASSED");
        else $display("%0d threshold checks FAILED", errs);
        $finish;
    end
endmodule

