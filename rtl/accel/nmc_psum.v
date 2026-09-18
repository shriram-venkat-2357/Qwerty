// Shift-accumulate partial-sum unit: one int accumulator per column.
// dot    = 2*popcount - ROWS  (binary +/-1 dot product)
// scaled = dot <<< shift_amt  (power-of-2 scale, folded batch-norm)
// acc   <= clr ? scaled : acc_en ? acc + scaled : acc
module nmc_psum #(
    parameter ROWS    = 128,
    parameter COLS    = 32,
    parameter ACC_W   = 32,
    parameter SHIFT_W = 3
)(
    input  wire clk,
    input  wire rst_n,
    input  wire clr,                 // first kernel position: load, don't add
    input  wire acc_en,              // popcount valid this cycle: accumulate
    input  wire [SHIFT_W-1:0] shift_amt,
    input  wire [COLS*PC_W-1:0] pc_in,          // packed: col0 in LSBs
    output wire [COLS*ACC_W-1:0] acc_out       // packed: col0 in LSBs
);

    localparam PC_W = $clog2(ROWS) + 1;

    reg [ACC_W-1:0] acc [0:COLS-1];

    genvar j;
    generate
        for (j = 0; j < COLS; j = j + 1) begin : col
            wire [PC_W-1:0]  pc     = pc_in[j*PC_W +: PC_W];
            wire [ACC_W-1:0] two_pc = {{(ACC_W-PC_W-1){1'b0}}, pc, 1'b0};
            wire [ACC_W-1:0] dot    = two_pc - ROWS;   // wraps to 2's complement
            wire [ACC_W-1:0] scaled = dot << shift_amt; // left shift: sign-safe

            always @(posedge clk or negedge rst_n) begin
                if (!rst_n)      acc[j] <= {ACC_W{1'b0}};
                else if (clr)    acc[j] <= scaled;
                else if (acc_en) acc[j] <= acc[j] + scaled;
            end

            assign acc_out[j*ACC_W +: ACC_W] = acc[j];
        end
    endgenerate

endmodule
