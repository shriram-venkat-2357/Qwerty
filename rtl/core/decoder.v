module decoder (
    input  wire [31:0] instr,
    output wire [6:0]  opcode,
    output wire [4:0]  rd,
    output wire [2:0]  funct3,
    output wire [4:0]  rs1,
    output wire [4:0]  rs2,
    output wire [6:0]  funct7,
    output wire [31:0] imm_i,   // I-type immediate
    output wire [31:0] imm_s,   // S-type immediate
    output wire [31:0] imm_b,   // B-type immediate
    output wire [31:0] imm_u,   // U-type immediate
    output wire [31:0] imm_j    // J-type immediate
);

    assign opcode = instr[6:0];
    assign rd     = instr[11:7];
    assign funct3 = instr[14:12];
    assign rs1    = instr[19:15];
    assign rs2    = instr[24:20];
    assign funct7 = instr[31:25];

    // I-type immediate (sign-extended)
    assign imm_i = {{20{instr[31]}}, instr[31:20]};

    // S-type immediate (sign-extended)
    assign imm_s = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    // B-type immediate (sign-extended)
    assign imm_b = {{19{instr[31]}}, instr[31], instr[7],
                    instr[30:25], instr[11:8], 1'b0};

    // U-type immediate
    assign imm_u = {instr[31:12], 12'd0};

    // J-type immediate (sign-extended)
    assign imm_j = {{11{instr[31]}}, instr[31], instr[19:12],
                    instr[20], instr[30:21], 1'b0};

endmodule
