module rv32_fetch_decode_stub (
    input  wire        clk,
    input  wire        rst_n,
    output reg  [31:0] pc,
    output reg  [31:0] instr,
    output wire [6:0]  opcode
);

    // Simple fetch skeleton.
    // For now, PC increments by 4 every cycle.
    // Instruction is fixed to NOP: addi x0, x0, 0

    localparam [31:0] NOP_INSTR = 32'h0000_0013;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc    <= 32'h0000_0000;
            instr <= NOP_INSTR;
        end else begin
            pc    <= pc + 32'd4;
            instr <= NOP_INSTR;
        end
    end

    assign opcode = instr[6:0];

endmodule
