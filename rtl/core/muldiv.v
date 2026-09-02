// RV32M multiply/divide unit (single-cycle, combinational)
module muldiv (
    input  wire [31:0] a,
    input  wire [31:0] b,
    input  wire [2:0]  funct3,
    output reg  [31:0] result
);

    // Products (computed in 64-bit context)
    wire signed [63:0] s_prod   = $signed(a) * $signed(b);
    wire signed [64:0] hsu_prod = $signed(a) * $signed({1'b0, b});
    wire        [63:0] u_prod   = {32'd0, a} * {32'd0, b};

    // Special cases per RISC-V spec
    wire div_by_zero = (b == 32'd0);
    wire overflow    = (a == 32'h8000_0000) && (b == 32'hFFFF_FFFF);

    wire signed [31:0] sa = a;
    wire signed [31:0] sb = b;

    always @(*) begin
        case (funct3)
            3'b000:  result = s_prod[31:0];                                  // MUL
            3'b001:  result = s_prod[63:32];                                 // MULH
            3'b010:  result = hsu_prod[63:32];                               // MULHSU
            3'b011:  result = u_prod[63:32];                                 // MULHU
            3'b100:  result = div_by_zero ? 32'hFFFF_FFFF :
                              overflow    ? 32'h8000_0000 :
                              (sa / sb);                                     // DIV
            3'b101:  result = div_by_zero ? 32'hFFFF_FFFF : (a / b);         // DIVU
            3'b110:  result = div_by_zero ? a :
                              overflow    ? 32'd0 :
                              (sa % sb);                                     // REM
            3'b111:  result = div_by_zero ? a : (a % b);                     // REMU
            default: result = 32'd0;
        endcase
    end

endmodule
