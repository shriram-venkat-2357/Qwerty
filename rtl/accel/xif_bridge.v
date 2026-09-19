// xif_bridge: taps the EX stage and turns custom-0 instructions into
// sequencer requests. Non-blocking ops issue for one cycle; nmc.rd
// (funct3=011) holds the pipeline in EX while the sequencer is busy.
module xif_bridge (
    input  wire [6:0]  opcode,
    input  wire [2:0]  funct3,
    input  wire [31:0] rs1_data,
    input  wire [31:0] rs2_data,
    input  wire        flush,      // branch_flush || ex_trap
    input  wire        busy,       // sequencer busy
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
    assign rd_stall   = is_rd && busy && !flush;
    assign rd_sel     = is_rd;

endmodule
