`define NMC
module rv32_pipeline #(
    parameter IMEM_FILE = "program.hex"
) (
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

    // --- EX stage: M-extension and CSR ---
    wire [31:0] ex_muldiv_result;
    wire [31:0] ex_csr_rdata;
    wire ex_is_m_ext = (ex_opcode == 7'b0110011) && (ex_funct7 == 7'b0000001);
    wire ex_is_csr   = (ex_opcode == 7'b1110011);
    wire [31:0] ex_result;
    wire        ex_trap;
    wire        ex_mret;
    wire [31:0] ex_trap_cause;
    wire        ex_csr_we;
    reg  [31:0] ex_csr_new;
    wire [31:0] csr_mtvec;
    wire [31:0] csr_mepc;
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
    wire        if_stall;
    wire        id_stall;
    wire        id_flush;
    wire        ifid_flush;
    wire        ex_flush;
    // --- NMC dispatch wires (driven under `ifdef NMC at bottom) ---
    wire        nmc_issue, nmc_stall, nmc_rd_sel;
    wire [2:0]  nmc_funct3;
    wire [31:0] nmc_rs1, nmc_rs2;
    wire [31:0] nmc_rd_data;
    wire [31:0] seq_b_addr, dmem_b_rdata;
    wire        seq_we_row, seq_act_valid;
    wire [6:0]  seq_wr_row;
    wire [31:0] seq_wr_data;
    wire [127:0] seq_act_out;
    wire        nmc_out_valid;
    wire [31:0] nmc_out_data;
    wire        seq_busy, seq_done, seq_error, seq_ready;

    // --- Forwarding ---
    wire [1:0] forward_a;
    wire [1:0] forward_b;
    // ============================================================
    // IF STAGE
    // ============================================================

    imem #(.FILE(IMEM_FILE)) u_imem (
        .addr  (pc),
        .instr (instr)
    );

    // PC update logic
    wire [31:0] next_pc;
    assign next_pc = ex_trap                           ? csr_mtvec :
                     ex_mret                           ? csr_mepc  :
                     (mem_branch && mem_branch_taken)  ? mem_branch_target :
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
        .flush       (if_id_flush),
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
    // csrr* instructions write rd (ecall/mret do not)
    // Immediate selection
    wire id_csr_read      = (id_opcode == 7'h73) && (id_funct3 != 3'b000);
    wire id_nmc_rd        = (id_opcode == 7'h0B) && (id_funct3 == 3'b011);
    wire id_reg_write_eff = id_reg_write || id_csr_read || id_nmc_rd;

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
    // HAZARD CONTROL (with forwarding)
    // Forwarding resolves every dependency except load-use.
    // Load-use = 1-cycle interlock:
    //   freeze PC + IF/ID, bubble ID/EX so the load advances to MEM;
    //   data then arrives via MEM/WB -> EX forwarding.
    // NEVER hold ID/EX here: holding it keeps the load in EX and
    // deadlocks (this was the old naive-logic bug).
    // ============================================================

    wire load_use_hazard = ex_mem_read && (ex_rd != 5'd0) &&
        ((ex_rd == id_rs1 && id_opcode != 7'b0110111 && id_opcode != 7'b0010111 && id_opcode != 7'b1101111) ||
         (ex_rd == id_rs2 && id_opcode != 7'b0110111 && id_opcode != 7'b0010111 && id_opcode != 7'b1101111));

    wire branch_flush = (mem_branch && mem_branch_taken) || mem_jump;
    // custom-0 waits in ID (bubbling EX) until the sequencer is idle:
    // operands stay correct via regfile re-read + normal forwarding
    wire nmc_wait = (id_opcode == 7'h0B) && (seq_busy || nmc_issue) && !branch_flush;

    assign if_stall = (load_use_hazard && !branch_flush && !ex_trap && !ex_mret)
                      || nmc_wait;
    assign id_stall = 1'b0;   // ID/EX must never hold
    wire if_id_flush = branch_flush || ex_trap || ex_mret;  // kill IF/ID only on wrong path
    assign id_flush  = branch_flush || (load_use_hazard && !branch_flush)
                                    || ex_trap || ex_mret || nmc_wait;  // bubble ID/EX
    assign ex_flush = branch_flush || ex_trap;   // trap instr must not reach MEM
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
        .reg_write_in  (id_reg_write_eff),
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


    // Forwarding unit
    forwarding_unit u_fwd (
        .ex_rs1_addr  (ex_rs1_addr),
        .ex_rs2_addr  (ex_rs2_addr),
        .mem_reg_write(mem_reg_write),
        .mem_rd       (mem_rd),
        .wb_reg_write (wb_reg_write),
        .wb_rd        (wb_rd),
        .forward_a    (forward_a),
        .forward_b    (forward_b)
    );

    alu_control u_alu_ctrl (
        .funct3  (ex_funct3),
        .funct7  (ex_funct7),
        .alu_op  (ex_alu_op),
        .alu_ctrl(ex_alu_ctrl)
    );

    // Forwarded register values
    wire [31:0] fwd_rs1_data = (forward_a == 2'b10) ? mem_alu_result :
                                (forward_a == 2'b01) ? wb_write_data :
                                ex_rs1_data;

    wire [31:0] fwd_rs2_data = (forward_b == 2'b10) ? mem_alu_result :
                                (forward_b == 2'b01) ? wb_write_data :
                                ex_rs2_data;

    // ALU inputs (using forwarded values)
    assign ex_alu_a = ex_lui ? 32'd0 : ex_auipc ? ex_pc : fwd_rs1_data;
    assign ex_alu_b = (ex_alu_src | ex_lui) ? ex_imm : fwd_rs2_data;

    alu u_alu (
        .a     (ex_alu_a),
        .b     (ex_alu_b),
        .op    (ex_alu_ctrl),
        .result(ex_alu_result),
        .zero  (ex_alu_zero)
    );
    // RV32M unit
    muldiv u_muldiv (
        .a      (fwd_rs1_data),
        .b      (fwd_rs2_data),
        .funct3 (ex_funct3),
        .result (ex_muldiv_result)
    );

    // ---- SYSTEM decode in EX ----
    wire ex_system  = (ex_opcode == 7'h73);
    wire ex_ecall   = ex_system && (ex_funct3 == 3'b000) && (ex_imm[11:0] == 12'h000);
    assign ex_mret  = ex_system && (ex_funct3 == 3'b000) && (ex_imm[11:0] == 12'h302);

    wire ex_legal_opcode = (ex_opcode == 7'h37) || (ex_opcode == 7'h17) ||
                           (ex_opcode == 7'h6F) || (ex_opcode == 7'h67) ||
                           (ex_opcode == 7'h63) || (ex_opcode == 7'h03) ||
                           (ex_opcode == 7'h23) || (ex_opcode == 7'h13) ||
                           (ex_opcode == 7'h33) || (ex_opcode == 7'h73) ||
                           (ex_opcode == 7'h0B);   // custom-0 = legal NOP stub

    wire ex_illegal = (!ex_legal_opcode) ||
                      (ex_system && (ex_funct3 == 3'b000) &&
                       (ex_imm[11:0] != 12'h000) && (ex_imm[11:0] != 12'h302));

    assign ex_trap       = ex_ecall || ex_illegal;
    assign ex_trap_cause = ex_ecall ? 32'd11 : 32'd2;  // 11=M-mode ecall, 2=illegal

    // ---- CSR read-modify-write value (computed in EX) ----
    wire [31:0] ex_csr_src = ex_funct3[2] ? {27'd0, ex_instr[19:15]} : fwd_rs1_data;

    always @(*) begin
        case (ex_funct3[1:0])
            2'b01:   ex_csr_new = ex_csr_src;                  // csrrw(i)
            2'b10:   ex_csr_new = ex_csr_rdata | ex_csr_src;   // csrrs(i)
            default: ex_csr_new = ex_csr_rdata & ~ex_csr_src;  // csrrc(i)
        endcase
    end

    // Write enable per spec: csrrw(i) always; csrrs/c only if src != 0.
    // Killed if this instruction is on a wrong path (flush) or is a trap.
    assign ex_csr_we = ex_system && (ex_funct3 != 3'b000) &&
                       ((ex_funct3[1:0] == 2'b01) || (ex_csr_src != 32'd0)) &&
                       !branch_flush && !ex_trap;

    csr_unit u_csr (
        .clk         (clk),
        .rst_n       (rst_n),
        .instret_inc (~if_stall & ~id_flush),
        .raddr       (ex_imm[11:0]),
        .rdata       (ex_csr_rdata),
        .we          (ex_csr_we),
        .waddr       (ex_imm[11:0]),
        .wdata       (ex_csr_new),
        .trap_we     (ex_trap),
        .trap_mepc   (ex_pc),
        .trap_cause  (ex_trap_cause),
        .nmc_status_in ({28'd0, seq_ready, seq_error, seq_done, seq_busy}),
        .mtvec_q     (csr_mtvec),
        .mepc_q      (csr_mepc)
    );

    // EX result MUX: M-ext / CSR / normal ALU
    assign ex_result = (ex_jump | ex_jalr) ? (ex_pc + 32'd4) : ex_is_m_ext ? ex_muldiv_result :
                       ex_is_csr   ? ex_csr_rdata     :
                       nmc_rd_sel  ? nmc_rd_data      :
                       ex_alu_result;
    // Branch condition evaluation
    always @(*) begin
        ex_branch_taken = 1'b0;
        if (ex_branch) begin
            case (ex_funct3)
                3'b000: ex_branch_taken = (fwd_rs1_data == fwd_rs2_data);
                3'b001: ex_branch_taken = (fwd_rs1_data != fwd_rs2_data);
                3'b100: ex_branch_taken = ($signed(fwd_rs1_data) < $signed(fwd_rs2_data));
                3'b101: ex_branch_taken = ($signed(fwd_rs1_data) >= $signed(fwd_rs2_data));
                3'b110: ex_branch_taken = (fwd_rs1_data < fwd_rs2_data);
                3'b111: ex_branch_taken = (fwd_rs1_data >= fwd_rs2_data);
                default: ex_branch_taken = 1'b0;
            endcase
        end
    end

    // Branch/jump target
    assign ex_branch_target = ex_jump   ? (ex_pc + ex_imm) :           // JAL
                              ex_jalr   ? ((fwd_rs1_data + ex_imm) & 32'hFFFFFFFE) : // JALR
                              (ex_pc + ex_imm);                        // Branch (imm_b already selected)

    // ============================================================
    // EX/MEM PIPELINE REGISTER
    // ============================================================

    ex_mem_reg u_ex_mem (
        .clk             (clk),
        .rst_n           (rst_n),
        .flush           (ex_flush),
        .alu_result_in   (ex_result),
        .rs2_data_in     (fwd_rs2_data),
        .rd_in           (ex_rd),
        .funct3_in       (ex_funct3),
        .reg_write_in    (ex_reg_write),
        .mem_read_in     (ex_mem_read),
        .mem_write_in    (ex_mem_write),
        .mem_to_reg_in   (ex_mem_to_reg),
        .branch_in       (ex_branch),
        .jump_in         (ex_jump | ex_jalr),
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
        .b_addr    (seq_b_addr),
        .b_rdata   (dmem_b_rdata),
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

`ifdef NMC
    xif_bridge u_bridge (
        .opcode      (ex_opcode),
        .funct3      (ex_funct3),
        .rs1_data    (fwd_rs1_data),
        .rs2_data    (fwd_rs2_data),
        .flush       (branch_flush || ex_trap),
        .busy        (seq_busy),
        .issue       (nmc_issue),
        .seq_funct3  (nmc_funct3),
        .seq_rs1     (nmc_rs1),
        .seq_rs2     (nmc_rs2),
        .rd_stall    (nmc_stall),
        .rd_sel      (nmc_rd_sel)
    );

    cim_sequencer u_seq (
        .clk        (clk),
        .rst_n      (rst_n),
        .issue      (nmc_issue),
        .funct3     (nmc_funct3),
        .rs1        (nmc_rs1),
        .rs2        (nmc_rs2),
        .rd_data    (nmc_rd_data),
        .busy       (seq_busy),
        .done_q     (seq_done),
        .error_q    (seq_error),
        .ready      (seq_ready),
        .we_row     (seq_we_row),
        .wr_row     (seq_wr_row),
        .wr_data    (seq_wr_data),
        .act_valid  (seq_act_valid),
        .act_out    (seq_act_out),
        .pool_valid (nmc_out_valid),
        .pool_data  (nmc_out_data),
        .b_addr     (seq_b_addr),
        .b_rdata    (dmem_b_rdata)
    );

    nmc_unit u_nmc (
        .clk        (clk),
        .rst_n      (rst_n),
        .we_row     (seq_we_row),
        .wr_row     (seq_wr_row),
        .wr_data    (seq_wr_data),
        .we_thr     (1'b0),
        .thr_addr   (5'd0),
        .thr_data   (32'd0),
        .shift_amt  (3'd0),
        .act_valid  (seq_act_valid),
        .act_in     (seq_act_out),
        .out_valid  (nmc_out_valid),
        .out_data   (nmc_out_data)
    );
`else
    assign nmc_stall  = 1'b0;
    assign nmc_rd_sel = 1'b0;
    assign nmc_rd_data = 32'd0;
    assign seq_b_addr = 32'd0;
    assign seq_busy   = 1'b0;
    assign seq_done   = 1'b0;
    assign seq_error  = 1'b0;
    assign seq_ready  = 1'b0;
`endif

endmodule
