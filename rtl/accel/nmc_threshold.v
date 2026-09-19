// Per-column threshold unit: binary activation = (acc >= thr), signed.
// Thresholds are per-column registers loaded once per layer.
module nmc_threshold #(
    parameter COLS  = 32,
    parameter ACC_W = 32,
    parameter THR_W = 32
)(
    input  wire clk,
    input  wire rst_n,
    // threshold load port
    input  wire we,
    input  wire [$clog2(COLS)-1:0] waddr,
    input  wire [THR_W-1:0] wdata,
    // compare port
    input  wire valid,
    input  wire [COLS*ACC_W-1:0] acc_in,   // packed: col0 in LSBs
    output reg  [COLS-1:0] act_out         // binary activation per column
);

    reg [THR_W-1:0] thr [0:COLS-1];
    integer k;

    // threshold register file
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (k = 0; k < COLS; k = k + 1)
                thr[k] <= {THR_W{1'b0}};
        end else if (we) begin
            thr[waddr] <= wdata;
        end
    end

    // signed compare, inclusive boundary
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            act_out <= {COLS{1'b0}};
        end else if (valid) begin
            for (k = 0; k < COLS; k = k + 1)
                act_out[k] <= ($signed(acc_in[k*ACC_W +: ACC_W]) >= $signed(thr[k]));
        end
    end

endmodule
