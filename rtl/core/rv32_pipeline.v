module rv32_pipeline (
    input  wire        clk,
    input  wire        rst_n,
    output wire [31:0] pc_out
);

    // ============================================================
    // SIGNAL DECLARATIONS
    // ============================================================

    // --- IF stage ---
    reg  [31:0] pc;
    wire [31:0] instr;
    wire [31:0] pc_plus4 = pc + 32'd4;

    // --- IF/ID register outputs ---
    wire [31:0] if_id_pc;
    wire [31:0] if_id_instr;

    // --- ID stage: decoded signals ---
    wire [6:0]  id_opcode;
    wire [4:0]  id_rd;
    wire [2:0]  id_funct3;
    wire [4:0]  id_rs1;
    wire [4:0]  id_rs2;
    wire [6:0]  id_funct7;
    wire [31:0] id_imm_i;
    wire [31:0] id_imm_s;
    wire [31:0] id_imm_b;
    wire [31:0] id_imm_u;
    wire [31:0] id_imm_j;

    wire [31:0] id_rs1_data;
    wire [31:0] id_rs2_data;

    // --- ID stage: control signals ---
    wire        id_reg_write;
    wire        id_mem_read;
    wire        id_mem_write;
    wire        id_mem_to_reg;
    wire        id_alu_src;
    wire        id_branch;
    wire        id_jump;
    wire        id_jalr;
    wire        id_lui;
    wire        id_auipc;
    wire [1:0]  id_alu_op;

    // --- Immediate selection ---
    wire [31:0] id_imm_sel;

    // --- ID/EX register outputs ---
    wire [31:0] ex_pc;
    wire [31:0] ex_instr;
    wire [31:0] ex_rs1_data;
    wire [31:0] ex_rs2_data;
    wire [31:0] ex_imm;
    wire [4:0]  ex_rd;
    wire [4:0]  ex_rs1_addr;
    wire [4:0]  ex_rs2_addr;
    wire [2:0]  ex_funct3;
    wire [6:0]  ex_funct7;
    wire [6:0]  ex_opcode;
    wire        ex_reg_write;
    wire        ex_mem_read;
    wire        ex_mem_write;
    wire        ex_mem_to_reg;
    wire        ex_alu_src;
    wire        ex_branch;
    wire        ex_jump;
    wire        ex_jalr;
    wire        ex_lui;
    wire        ex_auipc;
    wire [1:0]  ex_alu_op;

    // --- EX stage: ALU ---
    wire [3:0]  ex_alu_ctrl;
    wire [31:0] ex_alu_a;
    wire [31:0] ex_alu_b;
    wire [31:0] ex_alu_result;
    wire        ex_alu_zero;

    // --- EX stage: branch condition ---
    reg         ex_branch_taken;
    wire [31:0] ex_branch_target;

    // --- EX/MEM register outputs ---
    wire [31:0] mem_alu_result;
    wire [31:0] mem_rs2_data;
    wire [4:0]  mem_rd;
    wire [2:0]  mem_funct3;
    wire        mem_reg_write;
    wire        mem_mem_read;
    wire        mem_mem_write;
    wire        mem_mem_to_reg;
    wire        mem_branch;
    wire        mem_jump;
    wire        mem_branch_taken;
    wire [31:0] mem_branch_target;

    // --- MEM stage ---
    wire [31:0] mem_rdata;

    // --- MEM/WB register outputs ---
    wire [31:0] wb_alu_result;
    wire [31:0] wb_mem_rdata;
    wire [4:0]  wb_rd;
    wire        wb_reg_write;
    wire        wb_mem_to_reg;
    wire        wb_lui;
    wire        wb_imm_u_valid;
    wire [31:0] wb_imm_u;
    wire        wb_pc_plus4_valid;
    wire [31:0] wb_pc_plus4;

    // --- Write-back ---
    wire [31:0] wb_write_data;

    // --- Hazard / Stall / Flush ---
    wire         if_stall;
    wire         id_stall;
    wire         id_flush;
    wire         ex_flush;

    // ============================================================
    // IF STAGE
    // ============================================================

    imem u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // PC update logic
    wire [31:0] next_pc;
    assign next_pc = (mem_branch && mem_branch_taken) ? mem_branch_target :
                     (mem_jump)                        ? mem_branch_target :
                     if_stall                          ? pc :
                     pc_plus4;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            pc <= 32'h0000_0000;
        else
            pc <= next_pc;
    end

    // ============================================================
    // IF/ID PIPELINE REGISTER
    // ============================================================

    if_id_reg u_if_id (
        .clk      (clk),
        .rst_n    (rst_n),
        .stall    (if_stall),
        .flush    (id_flush),
        .pc_in    (pc),
        .instr_in (instr),
        .pc_out   (if_id_pc),
        .instr_out(if_id_instr)
    );

    // ============================================================
    // ID STAGE
    // ============================================================

    decoder u_decoder (
        .instr  (if_id_instr),
        .opcode (id_opcode),
        .rd     (id_rd),
        .funct3 (id_funct3),
        .rs1    (id_rs1),
        .rs2    (id_rs2),
        .funct7 (id_funct7),
        .imm_i  (id_imm_i),
        .imm_s  (id_imm_s),
        .imm_b  (id_imm_b),
        .imm_u  (id_imm_u),
        .imm_j  (id_imm_j)
    );

    control_unit u_control (
        .opcode    (id_opcode),
        .reg_write (id_reg_write),
        .mem_read  (id_mem_read),
        .mem_write (id_mem_write),
        .mem_to_reg(id_mem_to_reg),
        .alu_src   (id_alu_src),
        .branch    (id_branch),
        .jump      (id_jump),
        .jalr      (id_jalr),
        .lui       (id_lui),
        .auipc     (id_auipc),
        .alu_op    (id_alu_op)
    );

    // Register file read
    regfile u_regfile (
        .clk    (clk),
        .we     (wb_reg_write),
        .waddr  (wb_rd),
        .wdata  (wb_write_data),
        .raddr1 (id_rs1),
        .raddr2 (id_rs2),
        .rdata1 (id_rs1_data),
        .rdata2 (id_rs2_data)
    );

    // Immediate selection
    assign id_imm_sel = (id_opcode == 7'b0010011) ? id_imm_i :  // I-type
                        (id_opcode == 7'b0000011) ? id_imm_i :  // Load
                        (id_opcode == 7'b0100011) ? id_imm_s :  // Store
                        (id_opcode == 7'b1100011) ? id_imm_b :  // Branch
                        (id_opcode == 7'b0110111) ? id_imm_u :  // LUI
                        (id_opcode == 7'b0010111) ? id_imm_u :  // AUIPC
                        (id_opcode == 7'b1100111) ? id_imm_i :  // JALR
                        (id_opcode == 7'b1101111) ? id_imm_j :  // JAL
                        id_imm_i;

    // ============================================================
    // NAIVE HAZARD DETECTION (stall on any dependency)
    // No forwarding yet — this is the simple-but-correct version
    // ============================================================

    // Check if ID stage instruction depends on a result still in pipeline
    wire id_ex_hazard = (ex_reg_write && (ex_rd != 5'd0)) &&
                        ((ex_rd == id_rs1 && id_opcode != 7'b0110111 && id_opcode != 7'b0010111) ||
                         (ex_rd == id_rs2 && id_opcode != 7'b0110111 && id_opcode != 7'b0010111));

    wire ex_mem_hazard = (mem_reg_write && (mem_rd != 5'd0)) &&
                         ((mem_rd == id_rs1 && id_opcode != 7'b0110111 && id_opcode != 7'b0010111) ||
                          (mem_rd == id_rs2 && id_opcode != 7'b0110111 && id_opcode != 7'b0010111));

    wire mem_wb_hazard = (wb_reg_write && (wb_rd != 5'd0)) &&
                         ((wb_rd == id_rs1 && id_opcode != 7'b0110111 && id_opcode != 7'b0010111) ||
                          (wb_rd == id_rs2 && id_opcode != 7'b0110111 && id_opcode != 7'b0010111));

    wire data_hazard = id_ex_hazard || ex_mem_hazard || mem_wb_hazard;

    // Branch flush: when branch resolves in MEM, flush IF and ID
    wire branch_flush = (mem_branch && mem_branch_taken) || mem_jump;

    // Stall: hold IF and ID when there's a data hazard
    assign if_stall = data_hazard && !branch_flush;
    assign id_stall = data_hazard && !branch_flush;
    assign id_flush = branch_flush;
    assign ex_flush = branch_flush;

    // ============================================================
    // ID/EX PIPELINE REGISTER
    // ============================================================

    id_ex_reg u_id_ex (
        .clk           (clk),
        .rst_n         (rst_n),
        .stall         (id_stall),
        .flush         (id_flush),
        .pc_in         (if_id_pc),
        .instr_in      (if_id_instr),
        .rs1_data_in   (id_rs1_data),
        .rs2_data_in   (id_rs2_data),
        .imm_in        (id_imm_sel),
        .rd_in         (id_rd),
        .rs1_addr_in   (id_rs1),
        .rs2_addr_in   (id_rs2),
        .funct3_in     (id_funct3),
        .funct7_in     (id_funct7),
        .opcode_in     (id_opcode),
        .reg_write_in  (id_reg_write),
        .mem_read_in   (id_mem_read),
        .mem_write_in  (id_mem_write),
        .mem_to_reg_in (id_mem_to_reg),
        .alu_src_in    (id_alu_src),
        .branch_in     (id_branch),
        .jump_in       (id_jump),
        .jalr_in       (id_jalr),
        .lui_in        (id_lui),
        .auipc_in      (id_auipc),
        .alu_op_in     (id_alu_op),
        .pc_out        (ex_pc),
        .instr_out     (ex_instr),
        .rs1_data_out  (ex_rs1_data),
        .rs2_data_out  (ex_rs2_data),
        .imm_out       (ex_imm),
        .rd_out        (ex_rd),
        .rs1_addr_out  (ex_rs1_addr),
        .rs2_addr_out  (ex_rs2_addr),
        .funct3_out    (ex_funct3),
        .funct7_out    (ex_funct7),
        .opcode_out    (ex_opcode),
        .reg_write_out (ex_reg_write),
        .mem_read_out  (ex_mem_read),
        .mem_write_out (ex_mem_write),
        .mem_to_reg_out(ex_mem_to_reg),
        .alu_src_out   (ex_alu_src),
        .branch_out    (ex_branch),
        .jump_out      (ex_jump),
        .jalr_out      (ex_jalr),
        .lui_out       (ex_lui),
        .auipc_out     (ex_auipc),
        .alu_op_out    (ex_alu_op)
    );

    // ============================================================
    // EX STAGE
    // ============================================================

    alu_control u_alu_ctrl (
        .funct3  (ex_funct3),
        .funct7  (ex_funct7),
        .alu_op  (ex_alu_op),
        .alu_ctrl(ex_alu_ctrl)
    );

    // ALU inputs
    assign ex_alu_a = ex_auipc ? ex_pc : ex_rs1_data;
    assign ex_alu_b = ex_alu_src ? ex_imm : ex_rs2_data;

    alu u_alu (
        .a     (ex_alu_a),
        .b     (ex_alu_b),
        .op    (ex_alu_ctrl),
        .result(ex_alu_result),
        .zero  (ex_alu_zero)
    );

    // Branch condition evaluation
    always @(*) begin
        ex_branch_taken = 1'b0;
        if (ex_branch) begin
            case (ex_funct3)
                3'b000: ex_branch_taken = (ex_rs1_data == ex_rs2_data);
                3'b001: ex_branch_taken = (ex_rs1_data != ex_rs2_data);
                3'b100: ex_branch_taken = ($signed(ex_rs1_data) < $signed(ex_rs2_data));
                3'b101: ex_branch_taken = ($signed(ex_rs1_data) >= $signed(ex_rs2_data));
                3'b110: ex_branch_taken = (ex_rs1_data < ex_rs2_data);
                3'b111: ex_branch_taken = (ex_rs1_data >= ex_rs2_data);
                default: ex_branch_taken = 1'b0;
            endcase
        end
    end

    // Branch/jump target
    assign ex_branch_target = ex_jump   ? (ex_pc + ex_imm) :           // JAL
                              ex_jalr   ? ((ex_rs1_data + ex_imm) & 32'hFFFFFFFE) : // JALR
                              (ex_pc + ex_imm);                        // Branch (imm_b already selected)

    // ============================================================
    // EX/MEM PIPELINE REGISTER
    // ============================================================

    ex_mem_reg u_ex_mem (
        .clk             (clk),
        .rst_n           (rst_n),
        .flush           (ex_flush),
        .alu_result_in   (ex_alu_result),
        .rs2_data_in     (ex_rs2_data),
        .rd_in           (ex_rd),
        .funct3_in       (ex_funct3),
        .reg_write_in    (ex_reg_write),
        .mem_read_in     (ex_mem_read),
        .mem_write_in    (ex_mem_write),
        .mem_to_reg_in   (ex_mem_to_reg),
        .branch_in       (ex_branch),
        .jump_in         (ex_jump),
        .branch_taken_in (ex_branch_taken),
        .branch_target_in(ex_branch_target),
        .alu_result_out  (mem_alu_result),
        .rs2_data_out    (mem_rs2_data),
        .rd_out          (mem_rd),
        .funct3_out      (mem_funct3),
        .reg_write_out   (mem_reg_write),
        .mem_read_out    (mem_mem_read),
        .mem_write_out   (mem_mem_write),
        .mem_to_reg_out  (mem_mem_to_reg),
        .branch_out      (mem_branch),
        .jump_out        (mem_jump),
        .branch_taken_out(mem_branch_taken),
        .branch_target_out(mem_branch_target)
    );

    // ============================================================
    // MEM STAGE
    // ============================================================

    dmem u_dmem (
        .clk       (clk),
        .mem_read  (mem_mem_read),
        .mem_write (mem_mem_write),
        .funct3    (mem_funct3),
        .addr      (mem_alu_result),
        .wdata     (mem_rs2_data),
        .rdata     (mem_rdata)
    );

    // ============================================================
    // MEM/WB PIPELINE REGISTER
    // ============================================================

    mem_wb_reg u_mem_wb (
        .clk            (clk),
        .rst_n          (rst_n),
        .alu_result_in  (mem_alu_result),
        .mem_rdata_in   (mem_rdata),
        .rd_in          (mem_rd),
        .reg_write_in   (mem_reg_write),
        .mem_to_reg_in  (mem_mem_to_reg),
        .lui_in         (1'b0),
        .imm_u_valid_in (1'b0),
        .imm_u_in       (32'd0),
        .pc_plus4_valid_in(1'b0),
        .pc_plus4_in    (32'd0),
        .alu_result_out (wb_alu_result),
        .mem_rdata_out  (wb_mem_rdata),
        .rd_out         (wb_rd),
        .reg_write_out  (wb_reg_write),
        .mem_to_reg_out (wb_mem_to_reg),
        .lui_out        (wb_lui),
        .imm_u_valid_out(wb_imm_u_valid),
        .imm_u_out      (wb_imm_u),
        .pc_plus4_valid_out(wb_pc_plus4_valid),
        .pc_plus4_out   (wb_pc_plus4)
    );

    // ============================================================
    // WB STAGE
    // ============================================================

    assign wb_write_data = wb_mem_to_reg ? wb_mem_rdata : wb_alu_result;

    assign pc_out = pc;

endmodule
