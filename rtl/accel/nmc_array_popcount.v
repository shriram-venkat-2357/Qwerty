module nmc_array_popcount #(
    parameter ROWS = 128,
    parameter COLS = 32
)(
    input  wire                    clk,
    input  wire                    rst_n,
    input  wire                    we,
    input  wire [$clog2(ROWS)-1:0] wr_row,
    input  wire [$clog2(COLS)-1:0] wr_col,
    input  wire                    wr_val,
    input  wire [$clog2(COLS)-1:0] act_col,
    input  wire                    act_bit,
    output wire [$clog2(ROWS):0]   popcount_result
);

    // Weight array: ROWS x COLS of 1-bit registers
    reg [COLS-1:0] weight_array [0:ROWS-1];

    integer i;
    initial begin
        for (i = 0; i < ROWS; i = i + 1)
            weight_array[i] = {COLS{1'b0}};
    end

    always @(posedge clk) begin
        if (we)
            weight_array[wr_row][wr_col] <= wr_val;
    end

    // XNOR across all rows for selected column
    wire [ROWS-1:0] xnor_results;

    genvar r;
    generate
        for (r = 0; r < ROWS; r = r + 1) begin : xnor_gen
            assign xnor_results[r] = ~(weight_array[r][act_col] ^ act_bit);
        end
    endgenerate

    // Popcount: count 1s
    reg [$clog2(ROWS):0] pc;
    integer k;

    always @(*) begin
        pc = {($clog2(ROWS)+1){1'b0}};
        for (k = 0; k < ROWS; k = k + 1) begin
            pc = pc + xnor_results[k];
        end
    end

    assign popcount_result = pc;

endmodule
