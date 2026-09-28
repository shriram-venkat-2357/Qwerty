// Physical-config DMEM: 1024x8 bytes in one 512x32 macro. Port A timing matches
// sim (macro register == sim rdata register). Port B = +1 cycle (0006(c)).
module dmem (
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [2:0]  funct3,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output wire [31:0] rdata,
    input  wire [31:0] b_addr,
    output wire [31:0] b_rdata
);
    reg [3:0] wmask;
    always @* case (funct3[1:0])
        2'b00:   wmask = mem_write ? (4'b0001 << addr[1:0]) : 4'b0000;
        2'b01:   wmask = mem_write ? (4'b0011 << {addr[1],1'b0}) : 4'b0000;
        default: wmask = mem_write ? 4'b1111 : 4'b0000;
    endcase
    sky130_sram_2kbyte_1rw1r_32x512_8 u_macro (
        .clk0(clk), .clk1(clk), .csb0(~(mem_read | mem_write)), .web0(~mem_write),
        .wmask0(wmask), .addr0(addr[10:2]), .din0(wdata), .dout0(rdata),
        .csb1(1'b0), .addr1(b_addr[10:2]), .dout1(b_rdata)
    );
endmodule
