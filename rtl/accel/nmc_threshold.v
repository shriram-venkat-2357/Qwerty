// nmc_threshold.v — per-column signed inclusive threshold compare (WP2)
// act_out[k] = (acc_in[k] >= thr[k]), registered on `valid` (pend1) cycle.
// Decision 0002: synchronous per-column threshold write port (we/waddr/wdata),
// driven by cim_sequencer's nmc.cfg (custom-0, funct3 = 3'b100).
module nmc_threshold #(
    parameter COLS  = 32,
    parameter ACC_W = 32,
    parameter THR_W = 32
)(
    input  wire clk,
    input  wire rst_n,
    // --- Decision 0002 config write port (nmc.cfg) ---
    input  wire we,
    input  wire [$clog2(COLS)-1:0] waddr,
    input  wire [THR_W-1:0] wdata,
    // --- datapath ---
    input  wire valid,
    input  wire [COLS*ACC_W-1:0] acc_in,
    output reg  [COLS-1:0] act_out
);
    reg [COLS*THR_W-1:0] thr;
    integer k;

    // Threshold register file: reset to 0; synchronous per-column write
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            thr <= {COLS*THR_W{1'b0}};
        end else if (we) begin
            thr[waddr*THR_W +: THR_W] <= wdata;
        end
    end

    // act = (acc >= thr), signed, inclusive
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_out <= {COLS{1'b0}};
        end else if (valid) begin
            for (k = 0; k < COLS; k = k + 1)
                act_out[k] <= ($signed(acc_in[k*ACC_W +: ACC_W]) >=
                               $signed(thr[k*THR_W +: THR_W]));
        end
    end
endmodule
