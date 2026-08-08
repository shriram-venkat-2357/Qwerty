module rv32_single_cycle (
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] pc_out
);

    // ---- Program Counter ----
    reg [31:0] pc;

    // ---- Instruction Memory ----
    wire [31:0] instr;

    imem u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // ---- Decoder ----
    wire [6:0]  opcode;
    wire [4:0]  rd;
    wire [2:0]  funct3;
    wire [4:0]  rs1;
    wire [4:0]  rs2;
    wire [6:0]  funct7;
    wire [31:0] imm_i;
    wire [31:0] imm_s;
    wire [31:0] imm_b;
    wire [31:0] imm_u;
    wire [31:0] imm_j;

    decoder u_decoder (
        .instr (instr),
        .opcode (opcode),
        .rd     (rd),
        .funct3 (funct3),
        .rs1    (rs1),
        .rs2    (rs2),
        .funct7 (funct7),
        .imm_i  (imm_i),
        .imm_s  (imm_s),
        .imm_b  (imm_b),
        .imm_u  (imm_u),
        .imm_j  (imm_j)
    );

    // ---- Control Unit ----
    wire        reg_write;
    wire        mem_read;
    wire        mem_write;
    wire        mem_to_reg;
    wire        alu_src;
    wire        branch;
    wire        jump;
    wire        jalr;
    wire        lui;
    wire        auipc;
    wire [1:0]  alu_op;

    control_unit u_control (
        .opcode    (opcode),
        .reg_write (reg_write),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .mem_to_reg(mem_to_reg),
        .alu_src   (alu_src),
        .branch    (branch),
        .jump      (jump),
        .jalr      (jalr),
        .lui       (lui),
        .auipc     (auipc),
        .alu_op    (alu_op)
    );

    // ---- Register File ----
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    wire [31:0] write_data;

    regfile u_regfile (
        .clk    (clk),
        .we     (reg_write),
        .waddr  (rd),
        .wdata  (write_data),
        .raddr1 (rs1),
        .raddr2 (rs2),
        .rdata1 (rs1_data),
        .rdata2 (rs2_data)
    );

    // ---- ALU Input Selection ----
    // ALU input A: rs1 data, or PC for AUIPC
    wire [31:0] alu_a = auipc ? pc : rs1_data;

    // ALU input B: rs2 data or immediate
    wire [31:0] imm_sel;

    // Select the right immediate based on instruction type
    assign imm_sel = (opcode == 7'b0010011) ? imm_i :  // I-type
                     (opcode == 7'b0000011) ? imm_i :  // Load
                     (opcode == 7'b0100011) ? imm_s :  // Store
                     (opcode == 7'b1100011) ? imm_b :  // Branch
                     (opcode == 7'b0110111) ? imm_u :  // LUI
                     (opcode == 7'b0010111) ? imm_u :  // AUIPC
                     (opcode == 7'b1100111) ? imm_i :  // JALR
                     imm_i;                             // default

    wire [31:0] alu_b = alu_src ? imm_sel : rs2_data;

    // ---- ALU Control ----
    wire [3:0] alu_ctrl;

    alu_control u_alu_ctrl (
        .funct3  (funct3),
        .funct7  (funct7),
        .alu_op  (alu_op),
        .alu_ctrl(alu_ctrl)
    );

    // ---- ALU ----
    wire [31:0] alu_result;
    wire        alu_zero;

    alu u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .op     (alu_ctrl),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // ---- Branch Condition Check ----
    reg branch_taken;

    always @(*) begin
        branch_taken = 1'b0;
        if (branch) begin
            case (funct3)
                3'b000: branch_taken = (rs1_data == rs2_data);  // BEQ
                3'b001: branch_taken = (rs1_data != rs2_data);  // BNE
                3'b100: branch_taken = ($signed(rs1_data) < $signed(rs2_data));  // BLT
                3'b101: branch_taken = ($signed(rs1_data) >= $signed(rs2_data)); // BGE
                3'b110: branch_taken = (rs1_data < rs2_data);   // BLTU
                3'b111: branch_taken = (rs1_data >= rs2_data);  // BGEU
                default: branch_taken = 1'b0;
            endcase
        end
    end

    // ---- Data Memory ----
    wire [31:0] mem_rdata;

    dmem u_dmem (
        .clk       (clk),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .funct3    (funct3),
        .addr      (alu_result),
        .wdata     (rs2_data),
        .rdata     (mem_rdata)
    );

    // ---- Write-Back MUX ----
    // Select what goes into the register file
    assign write_data = mem_to_reg ? mem_rdata :
                        lui         ? imm_u :
                        auipc       ? alu_result :
                        jump        ? (pc + 32'd4) :  // JAL: save return address
                        jalr        ? (pc + 32'd4) :  // JALR: save return address
                        alu_result;

    // ---- Next PC Logic ----
    wire [31:0] pc_plus4 = pc + 32'd4;
    wire [31:0] branch_target = pc + imm_b;
    wire [31:0] jal_target    = pc + imm_j;
    wire [31:0] jalr_target   = (rs1_data + imm_i) & 32'hFFFFFFFE;

    wire [31:0] next_pc;

    assign next_pc = jump       ? jal_target :
                     jalr       ? jalr_target :
                     branch_taken ? branch_target :
                     pc_plus4;

    // ---- PC Update ----
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h0000_0000;
        else
            pc <= next_pc;
    end

    assign pc_out = pc;

endmodule
