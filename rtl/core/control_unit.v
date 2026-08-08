module control_unit (
    input  wire [6:0] opcode,
    output reg        reg_write,  // register write enable
    output reg        mem_read,   // memory read enable
    output reg        mem_write,  // memory write enable
    output reg        mem_to_reg, // write data comes from memory
    output reg        alu_src,    // 0=rs2, 1=immediate
    output reg        branch,     // branch instruction
    output reg        jump,       // jump instruction (jal)
    output reg        jalr,       // jalr instruction
    output reg        lui,        // lui instruction
    output reg        auipc,      // auipc instruction
    output reg [1:0]  alu_op      // ALU operation select
);

    localparam OP_RTYPE  = 7'b0110011;
    localparam OP_ITYPE  = 7'b0010011;
    localparam OP_LOAD   = 7'b0000011;
    localparam OP_STORE  = 7'b0100011;
    localparam OP_BRANCH = 7'b1100011;
    localparam OP_JAL    = 7'b1101111;
    localparam OP_JALR   = 7'b1100111;
    localparam OP_LUI    = 7'b0110111;
    localparam OP_AUIPC  = 7'b0010111;

    always @(*) begin
        // Defaults (no operation)
        reg_write  = 1'b0;
        mem_read   = 1'b0;
        mem_write  = 1'b0;
        mem_to_reg = 1'b0;
        alu_src    = 1'b0;
        branch     = 1'b0;
        jump       = 1'b0;
        jalr       = 1'b0;
        lui        = 1'b0;
        auipc      = 1'b0;
        alu_op     = 2'b00;

        case (opcode)
            OP_RTYPE: begin
                reg_write = 1'b1;
                alu_op    = 2'b00;  // R-type
            end
            OP_ITYPE: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b01;  // I-type
            end
            OP_LOAD: begin
                reg_write  = 1'b1;
                mem_read   = 1'b1;
                mem_to_reg = 1'b1;
                alu_src    = 1'b1;
                alu_op     = 2'b10;  // ADD
            end
            OP_STORE: begin
                mem_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b10;  // ADD
            end
            OP_BRANCH: begin
                branch = 1'b1;
                alu_op = 2'b00;
            end
            OP_JAL: begin
                jump      = 1'b1;
                reg_write = 1'b1;
            end
            OP_JALR: begin
                jalr      = 1'b1;
                reg_write = 1'b1;
                alu_src   = 1'b1;
                alu_op    = 2'b01;
            end
            OP_LUI: begin
                lui       = 1'b1;
                reg_write = 1'b1;
            end
            OP_AUIPC: begin
                auipc     = 1'b1;
                reg_write = 1'b1;
            end
            default: begin
                // NOP or unknown
            end
        endcase
    end

endmodule
