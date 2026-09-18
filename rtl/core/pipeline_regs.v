// ============================================================
// IF/ID Pipeline Register
// ============================================================
module if_id_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,    // hold current values
    input  wire        flush,    // insert bubble (NOP)
    // Input from IF stage
    input  wire [31:0] pc_in,
    input  wire [31:0] instr_in,
    // Output to ID stage
    output reg  [31:0] pc_out,
    output reg  [31:0] instr_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out    <= 32'd0;
            instr_out <= 32'h0000_0013; // NOP: addi x0, x0, 0
        end else if (flush) begin
            pc_out    <= 32'd0;
            instr_out <= 32'h0000_0013; // NOP
        end else if (!stall) begin
            pc_out    <= pc_in;
            instr_out <= instr_in;
        end
        // if stall: hold current values (do nothing)
    end

endmodule


// ============================================================
// ID/EX Pipeline Register
// ============================================================
module id_ex_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        stall,
    input  wire        flush,
    // Input from ID stage
    input  wire [31:0] pc_in,
    input  wire [31:0] instr_in,
    input  wire [31:0] rs1_data_in,
    input  wire [31:0] rs2_data_in,
    input  wire [31:0] imm_in,
    input  wire [4:0]  rd_in,
    input  wire [4:0]  rs1_addr_in,
    input  wire [4:0]  rs2_addr_in,
    input  wire [2:0]  funct3_in,
    input  wire [6:0]  funct7_in,
    input  wire [6:0]  opcode_in,
    // Control signals
    input  wire        reg_write_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        mem_to_reg_in,
    input  wire        alu_src_in,
    input  wire        branch_in,
    input  wire        jump_in,
    input  wire        jalr_in,
    input  wire        lui_in,
    input  wire        auipc_in,
    input  wire [1:0]  alu_op_in,
    // Output to EX stage
    output reg  [31:0] pc_out,
    output reg  [31:0] instr_out,
    output reg  [31:0] rs1_data_out,
    output reg  [31:0] rs2_data_out,
    output reg  [31:0] imm_out,
    output reg  [4:0]  rd_out,
    output reg  [4:0]  rs1_addr_out,
    output reg  [4:0]  rs2_addr_out,
    output reg  [2:0]  funct3_out,
    output reg  [6:0]  funct7_out,
    output reg  [6:0]  opcode_out,
    output reg         reg_write_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         mem_to_reg_out,
    output reg         alu_src_out,
    output reg         branch_out,
    output reg         jump_out,
    output reg         jalr_out,
    output reg         lui_out,
    output reg         auipc_out,
    output reg  [1:0]  alu_op_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_out        <= 32'd0;
            instr_out     <= 32'h0000_0013;
            rs1_data_out  <= 32'd0;
            rs2_data_out  <= 32'd0;
            imm_out       <= 32'd0;
            rd_out        <= 5'd0;
            rs1_addr_out  <= 5'd0;
            rs2_addr_out  <= 5'd0;
            funct3_out    <= 3'd0;
            funct7_out    <= 7'd0;
            opcode_out    <= 7'h13;
            reg_write_out <= 1'b0;
            mem_read_out  <= 1'b0;
            mem_write_out <= 1'b0;
            mem_to_reg_out<= 1'b0;
            alu_src_out   <= 1'b0;
            branch_out    <= 1'b0;
            jump_out      <= 1'b0;
            jalr_out      <= 1'b0;
            lui_out       <= 1'b0;
            auipc_out     <= 1'b0;
            alu_op_out    <= 2'd0;
        end else if (flush) begin
            pc_out        <= 32'd0;
            instr_out     <= 32'h0000_0013;
            rs1_data_out  <= 32'd0;
            rs2_data_out  <= 32'd0;
            imm_out       <= 32'd0;
            rd_out        <= 5'd0;
            rs1_addr_out  <= 5'd0;
            rs2_addr_out  <= 5'd0;
            funct3_out    <= 3'd0;
            funct7_out    <= 7'd0;
            opcode_out    <= 7'h13;
            reg_write_out <= 1'b0;
            mem_read_out  <= 1'b0;
            mem_write_out <= 1'b0;
            mem_to_reg_out<= 1'b0;
            alu_src_out   <= 1'b0;
            branch_out    <= 1'b0;
            jump_out      <= 1'b0;
            jalr_out      <= 1'b0;
            lui_out       <= 1'b0;
            auipc_out     <= 1'b0;
            alu_op_out    <= 2'd0;
        end else if (!stall) begin
            pc_out        <= pc_in;
            instr_out     <= instr_in;
            rs1_data_out  <= rs1_data_in;
            rs2_data_out  <= rs2_data_in;
            imm_out       <= imm_in;
            rd_out        <= rd_in;
            rs1_addr_out  <= rs1_addr_in;
            rs2_addr_out  <= rs2_addr_in;
            funct3_out    <= funct3_in;
            funct7_out    <= funct7_in;
            opcode_out    <= opcode_in;
            reg_write_out <= reg_write_in;
            mem_read_out  <= mem_read_in;
            mem_write_out <= mem_write_in;
            mem_to_reg_out<= mem_to_reg_in;
            alu_src_out   <= alu_src_in;
            branch_out    <= branch_in;
            jump_out      <= jump_in;
            jalr_out      <= jalr_in;
            lui_out       <= lui_in;
            auipc_out     <= auipc_in;
            alu_op_out    <= alu_op_in;
        end
    end

endmodule


// ============================================================
// EX/MEM Pipeline Register
// ============================================================
module ex_mem_reg (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        flush,
    // Input from EX stage
    input  wire [31:0] alu_result_in,
    input  wire [31:0] rs2_data_in,
    input  wire [4:0]  rd_in,
    input  wire [2:0]  funct3_in,
    // Control signals
    input  wire        reg_write_in,
    input  wire        mem_read_in,
    input  wire        mem_write_in,
    input  wire        mem_to_reg_in,
    input  wire        branch_in,
    input  wire        jump_in,
    input  wire        branch_taken_in,
    input  wire [31:0] branch_target_in,
    // Output to MEM stage
    output reg  [31:0] alu_result_out,
    output reg  [31:0] rs2_data_out,
    output reg  [4:0]  rd_out,
    output reg  [2:0]  funct3_out,
    output reg         reg_write_out,
    output reg         mem_read_out,
    output reg         mem_write_out,
    output reg         mem_to_reg_out,
    output reg         branch_out,
    output reg         jump_out,
    output reg         branch_taken_out,
    output reg  [31:0] branch_target_out
);

    always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        alu_result_out <= 32'd0;
        rs2_data_out   <= 32'd0;
        rd_out         <= 5'd0;
        funct3_out     <= 3'd0;
        reg_write_out  <= 1'b0;
        mem_read_out   <= 1'b0;
        mem_write_out  <= 1'b0;
        mem_to_reg_out <= 1'b0;
        branch_out     <= 1'b0;
        jump_out       <= 1'b0;
        branch_taken_out <= 1'b0;
        branch_target_out <= 32'd0;
    end else if (flush) begin
        alu_result_out <= 32'd0;
        rs2_data_out   <= 32'd0;
        rd_out         <= 5'd0;
        funct3_out     <= 3'd0;
        reg_write_out  <= 1'b0;
        mem_read_out   <= 1'b0;
        mem_write_out  <= 1'b0;
        mem_to_reg_out <= 1'b0;
        branch_out     <= 1'b0;
        jump_out       <= 1'b0;
        branch_taken_out <= 1'b0;
        branch_target_out <= 32'd0;
    end else begin
        alu_result_out <= alu_result_in;
        rs2_data_out   <= rs2_data_in;
        rd_out         <= rd_in;
        funct3_out     <= funct3_in;
        reg_write_out  <= reg_write_in;
        mem_read_out   <= mem_read_in;
        mem_write_out  <= mem_write_in;
        mem_to_reg_out <= mem_to_reg_in;
        branch_out     <= branch_in;
        jump_out       <= jump_in;
        branch_taken_out <= branch_taken_in;
        branch_target_out <= branch_target_in;
    end
end

endmodule


// ============================================================
// MEM/WB Pipeline Register
// ============================================================
module mem_wb_reg (
    input  wire        clk,
    input  wire        rst_n,
    // Input from MEM stage
    input  wire [31:0] alu_result_in,
    input  wire [31:0] mem_rdata_in,
    input  wire [4:0]  rd_in,
    // Control signals
    input  wire        reg_write_in,
    input  wire        mem_to_reg_in,
    input  wire        lui_in,
    input  wire        imm_u_valid_in,
    input  wire [31:0] imm_u_in,
    input  wire        pc_plus4_valid_in,
    input  wire [31:0] pc_plus4_in,
    // Output to WB stage
    output reg  [31:0] alu_result_out,
    output reg  [31:0] mem_rdata_out,
    output reg  [4:0]  rd_out,
    output reg         reg_write_out,
    output reg         mem_to_reg_out,
    output reg         lui_out,
    output reg         imm_u_valid_out,
    output reg  [31:0] imm_u_out,
    output reg         pc_plus4_valid_out,
    output reg  [31:0] pc_plus4_out
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            alu_result_out   <= 32'd0;
            mem_rdata_out    <= 32'd0;
            rd_out           <= 5'd0;
            reg_write_out    <= 1'b0;
            mem_to_reg_out   <= 1'b0;
            lui_out          <= 1'b0;
            imm_u_valid_out  <= 1'b0;
            imm_u_out        <= 32'd0;
            pc_plus4_valid_out <= 1'b0;
            pc_plus4_out     <= 32'd0;
        end else begin
            alu_result_out   <= alu_result_in;
            mem_rdata_out    <= mem_rdata_in;
            rd_out           <= rd_in;
            reg_write_out    <= reg_write_in;
            mem_to_reg_out   <= mem_to_reg_in;
            lui_out          <= lui_in;
            imm_u_valid_out  <= imm_u_valid_in;
            imm_u_out        <= imm_u_in;
            pc_plus4_valid_out <= pc_plus4_valid_in;
            pc_plus4_out     <= pc_plus4_in;
        end
    end

endmodule
