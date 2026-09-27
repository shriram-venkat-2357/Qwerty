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


endmodule
