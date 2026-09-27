import os

psum_code = """
module nmc_psum #(
    parameter ROWS    = 128,
    parameter COLS    = 32,
    parameter ACC_W   = 32,
    parameter SHIFT_W = 3
)(
    input  wire clk,
    input  wire rst_n,
    input  wire clr,
    input  wire acc_en,
    input  wire [SHIFT_W-1:0] shift_amt,
    input  wire [COLS*($clog2(ROWS)+1)-1:0] pc_in,
    output wire [COLS*ACC_W-1:0] acc_out
);
    localparam PC_W = $clog2(ROWS) + 1;
    reg [COLS*ACC_W-1:0] acc;
    genvar j;
    generate
        for (j = 0; j < COLS; j = j + 1) begin : col
            wire [PC_W-1:0]  pc     = pc_in[j*PC_W +: PC_W];
            wire [ACC_W-1:0] two_pc = {{(ACC_W-PC_W-1){1'b0}}, pc, 1'b0};
            wire [ACC_W-1:0] dot    = two_pc - ROWS;
            wire [ACC_W-1:0] scaled = dot << shift_amt;
            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)      acc[j*ACC_W +: ACC_W] <= {ACC_W{1'b0}};
                else if (clr)    acc[j*ACC_W +: ACC_W] <= scaled;
                else if (acc_en) acc[j*ACC_W +: ACC_W] <= acc[j*ACC_W +: ACC_W] + scaled;
            end
            assign acc_out[j*ACC_W +: ACC_W] = acc[j*ACC_W +: ACC_W];
        end
    endgenerate
endmodule
"""

thr_code = """
module nmc_threshold #(
    parameter COLS  = 32,
    parameter ACC_W = 32,
    parameter THR_W = 32
)(
    input  wire clk,
    input  wire rst_n,
    input  wire we,
    input  wire [$clog2(COLS)-1:0] waddr,
    input  wire [THR_W-1:0] wdata,
    input  wire valid,
    input  wire [COLS*ACC_W-1:0] acc_in,
    output reg  [COLS-1:0] act_out
);
    reg [COLS*THR_W-1:0] thr;
    integer k;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            thr <= {COLS*THR_W{1'b0}};
        end else if (we) begin
            thr[waddr*THR_W +: THR_W] <= wdata;
        end
    end
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_out <= {COLS{1'b0}};
        end else if (valid) begin
            for (k = 0; k < COLS; k = k + 1)
                act_out[k] <= ($signed(acc_in[k*ACC_W +: ACC_W]) >= $signed(thr[k*THR_W +: THR_W]));
        end
    end
endmodule
"""

unit_code = """
module nmc_unit #(
    parameter ROWS    = 128,
    parameter COLS    = 32,
    parameter ACC_W   = 32,
    parameter THR_W   = 32,
    parameter SHIFT_W = 3,
    parameter KPOS    = 9
)(
    input  wire clk,
    input  wire rst_n,
    input  wire we_row,
    input  wire [$clog2(ROWS)-1:0] wr_row,
    input  wire [COLS-1:0] wr_data,
    input  wire we_thr,
    input  wire [$clog2(COLS)-1:0] thr_addr,
    input  wire [THR_W-1:0] thr_data,
    input  wire [SHIFT_W-1:0] shift_amt,
    input  wire act_valid,
    input  wire [ROWS-1:0] act_in,
    output wire out_valid,
    output wire [COLS-1:0] out_data
);
    localparam PC_W = $clog2(ROWS) + 1;
    reg [ROWS*COLS-1:0] wmem;
    integer r;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            wmem <= {ROWS*COLS{1'b0}};
        end else if (we_row) begin
            wmem[wr_row*COLS +: COLS] <= wr_data;
        end
    end
    wire [COLS*PC_W-1:0] pc_vec;
    genvar j;
    generate
        for (j = 0; j < COLS; j = j + 1) begin : pccol
            reg [PC_W-1:0] pc;
            integer ii;
            always @(*) begin
                pc = 0;
                for (ii = 0; ii < ROWS; ii = ii + 1)
                    pc = pc + (~(wmem[ii*COLS + j] ^ act_in[ii]));
            end
            assign pc_vec[j*PC_W +: PC_W] = pc;
        end
    endgenerate
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
"""

seq_code = """
module cim_sequencer #(
    parameter ROWS   = 128,
    parameter COLS   = 32,
    parameter FDEPTH = 64
)(
    input  wire        clk,
    input  wire        rst_n,
    input  wire        issue,
    input  wire [2:0]  funct3,
    input  wire [31:0] rs1,
    input  wire [31:0] rs2,
    output wire [31:0] rd_data,
    output wire        busy,
    output wire        done_q,
    output wire        error_q,
    output wire        ready,
    output reg         we_row,
    output reg  [$clog2(ROWS)-1:0] wr_row,
    output reg  [COLS-1:0] wr_data,
    output reg         act_valid,
    output reg  [ROWS-1:0] act_out,
    input  wire        pool_valid,
    input  wire [COLS-1:0] pool_data,
    output reg  [31:0] b_addr,
    input  wire [31:0] b_rdata
);
    localparam IDLE = 2'd0, LDW = 2'd1, LDA = 2'd2, RUN = 2'd3;
    reg [1:0]  state;
    reg [31:0] tot, cnt;
    reg [FDEPTH*32-1:0] fifo;
    reg [$clog2(FDEPTH):0] wptr, rptr, fcnt;
    reg [ROWS-1:0] asm_reg;
    reg [1:0]  w3;
    reg [COLS-1:0] res;
    reg        done_r, error_r;
    assign busy    = (state != IDLE);
    assign ready   = (state == IDLE);
    assign done_q  = done_r;
    assign error_q = error_r;
    assign rd_data = res;
    integer i;
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= IDLE; we_row <= 0; wr_row <= 0; wr_data <= 0;
            act_valid <= 0; act_out <= 0; b_addr <= 0;
            wptr <= 0; rptr <= 0; fcnt <= 0; tot <= 0; cnt <= 0;
            w3 <= 0; asm_reg <= 0; res <= 0; done_r <= 0; error_r <= 0;
            fifo <= {FDEPTH*32{1'b0}};
        end else begin
            act_valid <= 1'b0;
            if (pool_valid) res <= pool_data;
            case (state)
            IDLE: begin
                we_row <= 1'b0;
                if (issue) begin
                    done_r <= 1'b0;
                    case (funct3)
                    3'b000: begin state <= LDW; tot <= rs2; cnt <= 0; b_addr <= rs1; end
                    3'b001: begin
                        if (rs2 > FDEPTH) begin error_r <= 1'b1; done_r <= 1'b1; end
                        else begin state <= LDA; tot <= rs2; cnt <= 0; b_addr <= rs1; end
                    end
                    3'b010: begin
                        if (fcnt < 4) begin error_r <= 1'b1; done_r <= 1'b1; end
                        else begin state <= RUN; w3 <= 0; end
                    end
                    default: ;
                    endcase
                end
            end
            LDW: begin
                wr_data <= b_rdata;
                wr_row  <= cnt[$clog2(ROWS)-1:0];
                we_row  <= 1'b1;
                b_addr  <= b_addr + 32'd4;
                if (cnt == tot - 1) begin state <= IDLE; done_r <= 1'b1; end
                else cnt <= cnt + 1;
            end
            LDA: begin
                if (fcnt < FDEPTH) begin
                    fifo[wptr*32 +: 32] <= b_rdata;
                    wptr <= wptr + 1;
                    fcnt <= fcnt + 1;
                    b_addr <= b_addr + 32'd4;
                    if (cnt == tot - 1) begin state <= IDLE; done_r <= 1'b1; end
                    else cnt <= cnt + 1;
                end else begin
                    error_r <= 1'b1; state <= IDLE; done_r <= 1'b1;
                end
            end
            RUN: begin
                if (fcnt >= 1) begin
                    case (w3)
                    2'd0:   asm_reg[31:0]        <= fifo[rptr*32 +: 32];
                    2'd1:   asm_reg[63:32]       <= fifo[rptr*32 +: 32];
                    2'd2:   asm_reg[ROWS-33:ROWS-64] <= fifo[rptr*32 +: 32];
                    default: ;
                    endcase
                    if (w3 == 2'd3) begin
                        act_out   <= {fifo[rptr*32 +: 32], asm_reg[ROWS-33:0]};
                        act_valid <= 1'b1;
                        if (fcnt - 1 < 4) begin state <= IDLE; done_r <= 1'b1; end
                    end
                    rptr <= rptr + 1;
                    fcnt <= fcnt - 1;
                    w3   <= w3 + 1;
                end else begin
                    state <= IDLE; done_r <= 1'b1;
                end
            end
            endcase
        end
    end
endmodule
"""

files = {
    'rtl/accel/nmc_psum.v': psum_code,
    'rtl/accel/nmc_threshold.v': thr_code,
    'rtl/accel/nmc_unit.v': unit_code,
    'rtl/accel/cim_sequencer.v': seq_code
}

for path, code in files.items():
    with open(path, 'w') as f:
        f.write(code.strip() + '\n')
print("Files overwritten successfully.")
