module regfile (
    input  wire        clk,
    input  wire        we,       // write enable
    input  wire [4:0]  waddr,    // write address (rd)
    input  wire [31:0] wdata,    // write data
    input  wire [4:0]  raddr1,   // read address 1 (rs1)
    input  wire [4:0]  raddr2,   // read address 2 (rs2)
    output wire [31:0] rdata1,   // read data 1
    output wire [31:0] rdata2    // read data 2
);

    reg [31:0] regs [0:31];

    // x0 is always 0
    assign rdata1 = (raddr1 == 5'd0) ? 32'd0 : regs[raddr1];
    assign rdata2 = (raddr2 == 5'd0) ? 32'd0 : regs[raddr2];

    always @(posedge clk) begin
        if (we && (waddr != 5'd0)) begin
            regs[waddr] <= wdata;
        end
    end

endmodule
