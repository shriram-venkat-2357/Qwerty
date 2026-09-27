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
