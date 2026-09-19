// SoC top with build switch (plan 2.1):
//   Build A = scalar baseline (no accelerator)
//   Build C = + nmc_unit          (compile with -DNMC)
// xif_bridge / sequencer hookup of u_nmc arrives in Week 5.
module soc_top #(
    parameter IMEM_FILE = "program.hex"
)(
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] pc_out
);

    rv32_pipeline #(.IMEM_FILE(IMEM_FILE)) u_core (
        .clk    (clk),
        .rst_n  (rst_n),
        .pc_out (pc_out)
    );

`ifdef NMC
    wire        nmc_out_valid;
    wire [31:0] nmc_out_data;

    nmc_unit u_nmc (
        .clk       (clk),
        .rst_n     (rst_n),
        .we_row    (1'b0),
        .wr_row    (7'd0),
        .wr_data   (32'd0),
        .we_thr    (1'b0),
        .thr_addr  (5'd0),
        .thr_data  (32'd0),
        .shift_amt (3'd0),
        .act_valid (1'b0),
        .act_in    (128'd0),
        .out_valid (nmc_out_valid),
        .out_data  (nmc_out_data)
    );
`endif

endmodule
