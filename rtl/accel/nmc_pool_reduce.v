// 2x2 pool reduce: signed max over 4 sequential phases, per column.
// On binary (0/1) inputs, max == OR, so this also pools thresholded maps.
module nmc_pool_reduce #(
    parameter COLS = 32,
    parameter W    = 32
)(
    input  wire clk,
    input  wire rst_n,
    input  wire valid,
    input  wire first,              // first phase of a new 2x2 window
    input  wire last,               // fourth (final) phase of the window
    input  wire [COLS*W-1:0] din,   // packed: col0 in LSBs
    output reg  [COLS*W-1:0] dout,  // packed: col0 in LSBs
    output reg  dout_valid
);

    reg [COLS*W-1:0] run;           // running max of phases seen so far
    integer k;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            run        <= {COLS*W{1'b0}};
            dout       <= {COLS*W{1'b0}};
            dout_valid <= 1'b0;
        end else begin
            dout_valid <= valid && last;
            if (valid) begin
                for (k = 0; k < COLS; k = k + 1) begin
                    // update running max
                    if (first)
                        run[k*W +: W] <= din[k*W +: W];
                    else if ($signed(din[k*W +: W]) > $signed(run[k*W +: W]))
                        run[k*W +: W] <= din[k*W +: W];

                    // emit on final phase
                    if (last) begin
                        if (first)
                            dout[k*W +: W] <= din[k*W +: W];
                        else if ($signed(din[k*W +: W]) > $signed(run[k*W +: W]))
                            dout[k*W +: W] <= din[k*W +: W];
                        else
                            dout[k*W +: W] <= run[k*W +: W];
                    end
                end
            end
        end
    end

endmodule
