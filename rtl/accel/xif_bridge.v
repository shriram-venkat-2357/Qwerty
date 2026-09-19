// xif_bridge: purely combinational tap.
// The pipeline's ID-wait (nmc_wait) guarantees that a custom-0 instruction
// only enters EX when the sequencer is idle. Therefore, we just issue
// combinationally on the single EX cycle using the forwarded operands.
module xif_bridge (
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    input  wire        flush,
    input  wire        busy,
    output wire        issue,
    output wire [2:0]  seq_funct3,
    output wire [31:0] seq_rs1,
    output wire [31:0] seq_rs2,
    output wire        rd_stall,
    output wire        rd_sel
);

    wire is_nmc = (opcode == 7'h0B);
    wire is_rd  = is_nmc && (funct3 == 3'b011);

    assign issue      = is_nmc && !is_rd && !flush;
    assign seq_funct3 = funct3;
    assign seq_rs1    = rs1_data;
    assign seq_rs2    = rs2_data;
    assign rd_stall   = 1'b0;  // Blocking is handled by ID-wait
    assign rd_sel     = is_rd;

endmodule
