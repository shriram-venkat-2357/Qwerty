// nmc_unit standalone datapath (Week 4). Sequencer/xif hookup = Week 5.
module nmc_unit #(
    parameter ROWS    = 128,
    parameter COLS    = 32,
    parameter ACC_W   = 32,
    parameter THR_W   = 32,
    parameter SHIFT_W = 3,
    parameter KPOS    = 9      // kernel positions per output pixel (3x3 = 9)
)(
    input  wire clk,
    input  wire rst_n,
    // weight load: one full binary row per write
    input  wire we_row,
    input  wire [$clog2(ROWS)-1:0] wr_row,
    input  wire [COLS-1:0] wr_data,
    // threshold load (per column)
    input  wire we_thr,
    input  wire [$clog2(COLS)-1:0] thr_addr,
    input  wire [THR_W-1:0] thr_data,
    // layer config
    input  wire [SHIFT_W-1:0] shift_amt,
    // activation stream: one kernel position per act_valid
    input  wire act_valid,
    input  wire [ROWS-1:0] act_in,
    // pooled binary result per column
    output wire out_valid,
    output wire [COLS-1:0] out_data
);

    localparam PC_W = $clog2(ROWS) + 1;

    // ---- weight array (row-wide write) ----
    reg [COLS-1:0] wmem [0:ROWS-1];
    integer r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (r = 0; r < ROWS; r = r + 1)
                wmem[r] <= {COLS{1'b0}};
        end else if (we_row) begin
            wmem[wr_row] <= wr_data;
        end
    end

    // ---- XNOR + popcount per column (combinational) ----
    wire [COLS*PC_W-1:0] pc_vec;
    genvar j;
    generate
        for (j = 0; j < COLS; j = j + 1) begin : pccol
            reg [PC_W-1:0] pc;
            integer ii;
            always @(*) begin
                pc = 0;
                for (ii = 0; ii < ROWS; ii = ii + 1)
                    pc = pc + (~(wmem[ii][j] ^ act_in[ii]));
            end
            assign pc_vec[j*PC_W +: PC_W] = pc;
        end
    endgenerate

    // ---- mini control FSM (counters; sequencer replaces in Week 5) ----
    reg [$clog2(KPOS):0] pos_cnt;
    reg [1:0]  phase_cnt;
    reg        pend1, pend2;

    wire psum_clr   = act_valid && (pos_cnt == 0);
    wire psum_acc   = act_valid && (pos_cnt != 0);
    wire last_pos   = act_valid && (pos_cnt == KPOS-1);
    wire thr_valid  = pend1;
    wire pool_valid = pend2;
    wire pool_first = pool_valid && (phase_cnt == 0);
    wire pool_last  = pool_valid && (phase_cnt == 3);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pos_cnt   <= 0;
            phase_cnt <= 0;
            pend1     <= 1'b0;
            pend2     <= 1'b0;
        end else begin
            pend1 <= last_pos;
            pend2 <= pend1;
            if (act_valid) begin
                if (pos_cnt == KPOS-1) pos_cnt <= 0;
                else                   pos_cnt <= pos_cnt + 1;
            end
            if (pool_valid) begin
                if (pool_last) phase_cnt <= 0;
                else           phase_cnt <= phase_cnt + 1;
            end
        end
    end

    // ---- datapath chain ----
    wire [COLS*ACC_W-1:0] acc_out;
    nmc_psum #(.ROWS(ROWS), .COLS(COLS), .ACC_W(ACC_W), .SHIFT_W(SHIFT_W)) u_psum (
        .clk(clk), .rst_n(rst_n), .clr(psum_clr), .acc_en(psum_acc),
        .shift_amt(shift_amt), .pc_in(pc_vec), .acc_out(acc_out)
    );

    wire [COLS-1:0] act_bits;
    nmc_threshold #(.COLS(COLS), .ACC_W(ACC_W), .THR_W(THR_W)) u_thr (
        .clk(clk), .rst_n(rst_n), .we(we_thr), .waddr(thr_addr), .wdata(thr_data),
        .valid(thr_valid), .acc_in(acc_out), .act_out(act_bits)
    );

    // zero-extend binary acts to 2-bit signed-safe pool inputs
    wire [COLS*2-1:0] pool_din;
    genvar j2;
    generate
        for (j2 = 0; j2 < COLS; j2 = j2 + 1) begin : pext
            assign pool_din[j2*2 +: 2] = {1'b0, act_bits[j2]};
        end
    endgenerate

    wire [COLS*2-1:0] pool_dout;
    wire              pool_dout_valid;
    nmc_pool_reduce #(.COLS(COLS), .W(2)) u_pool (
        .clk(clk), .rst_n(rst_n), .valid(pool_valid),
        .first(pool_first), .last(pool_last),
        .din(pool_din), .dout(pool_dout), .dout_valid(pool_dout_valid)
    );

    assign out_valid = pool_dout_valid;
    genvar j3;
    generate
        for (j3 = 0; j3 < COLS; j3 = j3 + 1) begin : outx
            assign out_data[j3] = pool_dout[j3*2];
        end
    endgenerate

endmodule
