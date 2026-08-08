module forwarding_unit (
    // EX stage: source register addresses we need
    input  wire [4:0] ex_rs1_addr,
    input  wire [4:0] ex_rs2_addr,

    // MEM stage: what's available from EX/MEM register
    input  wire        mem_reg_write,
    input  wire [4:0]  mem_rd,

    // WB stage: what's available from MEM/WB register
    input  wire        wb_reg_write,
    input  wire [4:0]  wb_rd,

    // Output: forwarding select signals
    // 00 = no forwarding (use register file value)
    // 01 = forward from WB stage (MEM/WB)
    // 10 = forward from MEM stage (EX/MEM) — takes priority
    output reg  [1:0] forward_a,
    output reg  [1:0] forward_b
);

    always @(*) begin
        // Default: no forwarding
        forward_a = 2'b00;
        forward_b = 2'b00;

        // --- Forward for operand A (rs1) ---

        // Check EX/MEM first (more recent, higher priority)
        if (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs1_addr))
            forward_a = 2'b10;
        // Then check MEM/WB (older, lower priority)
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs1_addr))
            forward_a = 2'b01;

        // --- Forward for operand B (rs2) ---

        if (mem_reg_write && (mem_rd != 5'd0) && (mem_rd == ex_rs2_addr))
            forward_b = 2'b10;
        else if (wb_reg_write && (wb_rd != 5'd0) && (wb_rd == ex_rs2_addr))
            forward_b = 2'b01;
    end

endmodule
