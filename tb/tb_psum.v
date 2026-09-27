`timescale 1ns/1ps
module tb_psum;
    localparam ROWS = 8, COLS = 2, ACC_W = 16, SHIFT_W = 3, PC_W = 4;

    reg clk, rst_n, clr, acc_en;
    reg [SHIFT_W-1:0] shift_amt;
    reg [COLS*PC_W-1:0] pc_in;
    wire [COLS*ACC_W-1:0] acc_out;

    nmc_psum #(.ROWS(ROWS), .COLS(COLS), .ACC_W(ACC_W), .SHIFT_W(SHIFT_W)) u (
        .clk(clk), .rst_n(rst_n), .clr(clr), .acc_en(acc_en),
        .shift_amt(shift_amt), .pc_in(pc_in), .acc_out(acc_out)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer errs;
    wire signed [ACC_W-1:0] acc0 = acc_out[0*ACC_W +: ACC_W];
    wire signed [ACC_W-1:0] acc1 = acc_out[1*ACC_W +: ACC_W];

    initial begin
        errs = 0;
        rst_n = 0; clr = 0; acc_en = 0; shift_amt = 0; pc_in = 0;
        #20; rst_n = 1;

        // Cycle A: clr, pc = {col1=8, col0=8} -> dot=8 -> acc=8
        clr = 1; pc_in = {4'd8, 4'd8}; @(posedge clk); #1;
        clr = 0;
        if (acc0 !== 16'sd8 || acc1 !== 16'sd8) begin errs=errs+1;
            $display("FAIL clr-load: acc0=%0d acc1=%0d", acc0, acc1); end

        // Cycle B: acc_en, pc={4,0}, shift 0 -> col0 dot=-8 -> 0 ; col1 dot=0 -> 8
        acc_en = 1; pc_in = {4'd4, 4'd0}; @(posedge clk); #1;
        if (acc0 !== 16'sd0 || acc1 !== 16'sd8) begin errs=errs+1;
            $display("FAIL acc-add: acc0=%0d acc1=%0d", acc0, acc1); end

        // Cycle C: acc_en, pc={0,8}, shift 1 -> col0 -8<<1=-16 -> -16 ; col1 8<<1=16 -> 24
        shift_amt = 1; pc_in = {4'd8, 4'd0}; @(posedge clk); #1;
        if (acc0 !== -16'sd16 || acc1 !== 16'sd24) begin errs=errs+1;
            $display("FAIL shift-acc: acc0=%0d acc1=%0d", acc0, acc1); end

        // Idle: holds
        acc_en = 0; @(posedge clk); #1;
        if (acc0 !== -16'sd16 || acc1 !== 16'sd24) begin errs=errs+1;
            $display("FAIL hold: acc0=%0d acc1=%0d", acc0, acc1); end

        if (errs == 0) $display("ALL PSUM TESTS PASSED");
        else $display("%0d psum checks FAILED", errs);
        $finish;
    end
endmodule
