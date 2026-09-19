`timescale 1ns/1ps
module tb_sequencer;
    localparam COLS = 32;
    reg clk, rst_n, issue;
    reg [2:0] funct3;
    reg [31:0] rs1, rs2;
    wire [31:0] rd_data, b_rdata, b_addr_seen;
    wire busy, done_q, error_q, ready, we_row, act_valid;
    wire [6:0] wr_row;
    wire [31:0] wr_data;
    wire [127:0] act_out;

    reg [31:0] mem [0:255];
    assign b_rdata = mem[b_addr_seen[9:2]];

    reg [31:0] rows [0:127];
    always @(posedge clk) if (we_row) rows[wr_row] <= wr_data;

    reg [127:0] actcap [0:7];
    integer nact;
    always @(posedge clk) if (act_valid) begin actcap[nact] <= act_out; nact <= nact+1; end

    cim_sequencer #(.ROWS(128), .COLS(COLS)) u (
        .clk(clk), .rst_n(rst_n), .issue(issue), .funct3(funct3),
        .rs1(rs1), .rs2(rs2), .rd_data(rd_data),
        .busy(busy), .done_q(done_q), .error_q(error_q), .ready(ready),
        .we_row(we_row), .wr_row(wr_row), .wr_data(wr_data),
        .act_valid(act_valid), .act_out(act_out),
        .pool_valid(1'b0), .pool_data(32'd0),
        .b_addr(b_addr_seen), .b_rdata(b_rdata)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer errs, k;
    task wait_done;
        begin
            k = 0;
            while (!done_q && k < 500) begin @(posedge clk); k = k+1; end
            if (k >= 500) begin errs = errs+1; $display("FAIL timeout"); end
        end
    endtask

    initial begin
        errs = 0; nact = 0;
        for (k = 0; k < 16; k = k + 1) mem[k] = k + 32'h100;   // words 0..15
        rst_n = 0; issue = 0; funct3 = 0; rs1 = 0; rs2 = 0;
        #20; rst_n = 1; @(posedge clk);

        // ldw: 4 rows from word addr 0 (byte 0)
        funct3 = 0; rs1 = 0; rs2 = 4; issue = 1; @(posedge clk); issue = 0;
        wait_done; @(posedge clk); @(posedge clk);
        for (k = 0; k < 4; k = k + 1)
            if (rows[k] !== k + 32'h100) begin errs=errs+1;
                $display("FAIL ldw row %0d = %h", k, rows[k]); end

        // lda: 8 words from byte 16 (words 4..11)
        funct3 = 1; rs1 = 16; rs2 = 8; issue = 1; @(posedge clk); issue = 0;
        wait_done;
        if (u.fcnt !== 8) begin errs=errs+1; $display("FAIL fcnt=%0d", u.fcnt); end

        // run: 8 words = 2 activation vectors
        funct3 = 2; rs1 = 0; rs2 = 0; issue = 1; @(posedge clk); issue = 0;
        wait_done; @(posedge clk);
        if (nact !== 2) begin errs=errs+1; $display("FAIL nact=%0d", nact); end
        if (actcap[0] !== {32'h107, 32'h106, 32'h105, 32'h104}) begin
            errs=errs+1; $display("FAIL act0=%h", actcap[0]); end
        if (actcap[1] !== {32'h10B, 32'h10A, 32'h109, 32'h108}) begin
            errs=errs+1; $display("FAIL act1=%h", actcap[1]); end
        if (error_q !== 0) begin errs=errs+1; $display("FAIL error set"); end
        if (ready !== 1) begin errs=errs+1; $display("FAIL not ready"); end

        if (errs == 0) $display("ALL SEQUENCER TESTS PASSED");
        else $display("%0d sequencer checks FAILED", errs);
        $finish;
    end
endmodule
