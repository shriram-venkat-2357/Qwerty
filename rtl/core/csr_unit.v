// Zicsr: read-only counters + writable machine-mode trap CSRs
module csr_unit (
    input  wire         clk,
    input  wire         rst_n,
    input  wire         instret_inc,
    // Read port (used in EX)
    input  wire [11:0]  raddr,
    output wire [31:0]  rdata,
    // Instruction write port (applied at end of EX)
    input  wire         we,
    input  wire [11:0]  waddr,
    input  wire [31:0]  wdata,
    // Trap write port (priority over instruction write)
    input  wire         trap_we,
    input  wire [31:0]  trap_mepc,
    input  wire [31:0]  trap_cause,
    // Direct outputs for the PC mux
    output wire [31:0]  mtvec_q,
    output wire [31:0]  mepc_q
);

    reg [63:0] cycle_cnt;
    reg [63:0] instret_cnt;
    reg [31:0] mscratch, mepc, mcause, mtvec;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt   <= 64'd0;
            instret_cnt <= 64'd0;
            mscratch    <= 32'd0;
            mepc        <= 32'd0;
            mcause      <= 32'd0;
            mtvec       <= 32'd0;
        end else begin
            cycle_cnt <= cycle_cnt + 64'd1;
            if (instret_inc)
                instret_cnt <= instret_cnt + 64'd1;

            if (trap_we) begin
                mepc   <= trap_mepc;
                mcause <= trap_cause;
            end else if (we) begin
                case (waddr)
                    12'h340:  mscratch <= wdata;
                    12'h341:  mepc     <= wdata;
                    12'h342:  mcause   <= wdata;
                    12'h305:  mtvec    <= wdata;
                    default:  ;  // writes to other addrs ignored (incl. counters)
                endcase
            end
        end
    end

    assign mtvec_q = mtvec;
    assign mepc_q  = mepc;

    assign rdata = (raddr == 12'hC00) ? cycle_cnt[31:0]   :
                   (raddr == 12'hC80) ? cycle_cnt[63:32]  :
                   (raddr == 12'hC02) ? instret_cnt[31:0] :
                   (raddr == 12'hC82) ? instret_cnt[63:32]:
                   (raddr == 12'h340) ? mscratch :
                   (raddr == 12'h341) ? mepc :
                   (raddr == 12'h342) ? mcause :
                   (raddr == 12'h305) ? mtvec :
                   32'd0;

endmodule
