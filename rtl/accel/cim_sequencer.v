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
