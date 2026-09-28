// Physical-config IMEM: Sky130 2KB 1rw1r macro (512x32); addr[13:11] aliased.
// Replaces rtl/core/imem.v ONLY in scripts/synth_phys.ys. Requires 0006(a,b).
module imem #(parameter FILE = "program.hex")(
    input  wire        clk,
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    sky130_sram_2kbyte_1rw1r_32x512_8 u_macro (
        .clk0(clk), .clk1(clk), .csb0(1'b0), .web0(1'b1), .wmask0(4'b0000),
        .addr0(addr[10:2]), .din0(32'b0), .dout0(instr),
        .csb1(1'b1), .addr1(9'b0), .dout1()
    );
endmodule
