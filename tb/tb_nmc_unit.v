`timescale 1ns/1ps
module tb_nmc_unit;
    localparam ROWS = 8, COLS = 2, ACC_W = 16, THR_W = 16, SHIFT_W = 3, KPOS = 4;

    reg clk, rst_n, we_row, we_thr, act_valid;
    reg [$clog2(ROWS)-1:0] wr_row;
    reg [COLS-1:0] wr_data;
    reg [$clog2(COLS)-1:0] thr_addr;
    reg [THR_W-1:0] thr_data;
    reg [SHIFT_W-1:0] shift_amt;
    reg [ROWS-1:0] act_in;
    wire out_valid;
    wire [COLS-1:0] out_data;

    nmc_unit #(.ROWS(ROWS), .COLS(COLS), .ACC_W(ACC_W), .THR_W(THR_W),
               .SHIFT_W(SHIFT_W), .KPOS(KPOS)) u (
        .clk(clk), .rst_n(rst_n),
        .we_row(we_row), .wr_row(wr_row), .wr_data(wr_data),
        .we_thr(we_thr), .thr_addr(thr_addr), .thr_data(thr_data),
        .shift_amt(shift_amt), .act_valid(act_valid), .act_in(act_in),
        .out_valid(out_valid), .out_data(out_data)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer errs, rr, ph, p;
    reg [7:0] pat [0:3];
    reg got_valid;
    reg [COLS-1:0] cap;

    always @(posedge clk) begin
        if (out_valid) begin got_valid <= 1'b1; cap <= out_data; end
    end

    initial begin
        errs = 0; got_valid = 0; cap = 0;
        pat[0] = 8'hFF; pat[1] = 8'h00; pat[2] = 8'h0F; pat[3] = 8'hFF;
        rst_n = 0; we_row = 0; we_thr = 0; act_valid = 0;
        wr_row = 0; wr_data = 0; thr_addr = 0; thr_data = 0;
        shift_amt = 0; act_in = 0;
        #20; rst_n = 1;

        // weights: col0 = 1, col1 = 0 in every row
        for (rr = 0; rr < ROWS; rr = rr + 1) begin
            we_row = 1; wr_row = rr[$clog2(ROWS)-1:0]; wr_data = 2'b01;
            @(posedge clk); #1;
        end
        we_row = 0;

        // thresholds: col0 = 16, col1 = 100 (unreachable)
        we_thr = 1; thr_addr = 0; thr_data = 16'd16;  @(posedge clk); #1;
        thr_addr = 1; thr_data = 16'd100;              @(posedge clk); #1;
        we_thr = 0;

        // four pool phases, each = KPOS activation positions
        for (ph = 0; ph < 4; ph = ph + 1) begin
            for (p = 0; p < KPOS; p = p + 1) begin
                act_valid = 1; act_in = pat[ph];
                @(posedge clk); #1;
            end
            act_valid = 0;
            if (ph == 0) begin
                // peek accumulators after first compute: col0=+32, col1=-32
                if (u.u_psum.acc[0] !== 16'sd32 || u.u_psum.acc[1] !== -16'sd32) begin
                    errs = errs+1;
                    $display("FAIL acc: a0=%0d a1=%0d", u.u_psum.acc[0], u.u_psum.acc[1]);
                end
            end
            repeat (3) @(posedge clk);
        end

        repeat (6) @(posedge clk);

        if (!got_valid) begin errs = errs+1; $display("FAIL no out_valid"); end
        if (cap !== 2'b01)  begin errs = errs+1; $display("FAIL out: %b", cap); end

        if (errs == 0) $display("ALL NMC_UNIT TESTS PASSED");
        else $display("%0d nmc_unit checks FAILED", errs);
        $finish;
    end
endmodule
