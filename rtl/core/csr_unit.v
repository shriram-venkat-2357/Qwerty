// Zicsr: machine-mode cycle and instret counters (read-only)
module csr_unit (
    input  wire        clk,
    input  wire        rst_n,
    input  wire        instret_inc,
    input  wire [11:0] addr,
    output wire [31:0] rdata
);

    reg [63:0] cycle_cnt;
    reg [63:0] instret_cnt;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            cycle_cnt   <= 64'd0;
            instret_cnt <= 64'd0;
        end else begin
            cycle_cnt <= cycle_cnt + 64'd1;
            if (instret_inc)
                instret_cnt <= instret_cnt + 64'd1;
        end
    end

    assign rdata = (addr == 12'hC00) ? cycle_cnt[31:0]   :  // cycle
                   (addr == 12'hC80) ? cycle_cnt[63:32]  :  // cycleh
                   (addr == 12'hC02) ? instret_cnt[31:0] :  // instret
                   (addr == 12'hC82) ? instret_cnt[63:32]:  // instreth
                   32'd0;

endmodule
