module dmem (
    input  wire        clk,
    input  wire        mem_read,
    input  wire        mem_write,
    input  wire [2:0]  funct3,
    input  wire [31:0] addr,
    input  wire [31:0] wdata,
    output reg  [31:0] rdata,
    input  wire [31:0] b_addr,
    output wire [31:0] b_rdata
);

    // 256 words of data memory
    reg [7:0] mem [0:1023];

    integer i;

    // Initialize to zero
    initial begin
        for (i = 0; i < 1024; i = i + 1)
            mem[i] = 8'd0;
    end

    assign b_rdata = {mem[b_addr[9:0]+3], mem[b_addr[9:0]+2],
                      mem[b_addr[9:0]+1], mem[b_addr[9:0]]};

    // Read (combinational)
    always @(*) begin
        rdata = 32'd0;
        if (mem_read) begin
            case (funct3)
                3'b000: begin // LB (sign-extended byte)
                    rdata = {{24{mem[addr[9:0]][7]}}, mem[addr[9:0]]};
                end
                3'b001: begin // LH (sign-extended halfword)
                    rdata = {{16{mem[addr[9:0]+1][7]}},
                             mem[addr[9:0]+1], mem[addr[9:0]]};
                end
                3'b010: begin // LW (full word)
                    rdata = {mem[addr[9:0]+3], mem[addr[9:0]+2],
                             mem[addr[9:0]+1], mem[addr[9:0]]};
                end
                3'b100: begin // LBU (zero-extended byte)
                    rdata = {24'd0, mem[addr[9:0]]};
                end
                3'b101: begin // LHU (zero-extended halfword)
                    rdata = {16'd0, mem[addr[9:0]+1], mem[addr[9:0]]};
                end
                default: rdata = 32'd0;
            endcase
        end
    end

    // Write (on clock edge)
    always @(posedge clk) begin
        if (mem_write) begin
            case (funct3)
                3'b000: begin // SB
                    mem[addr[9:0]] = wdata[7:0];
                end
                3'b001: begin // SH
                    mem[addr[9:0]]   = wdata[7:0];
                    mem[addr[9:0]+1] = wdata[15:8];
                end
                3'b010: begin // SW
                    mem[addr[9:0]]   = wdata[7:0];
                    mem[addr[9:0]+1] = wdata[15:8];
                    mem[addr[9:0]+2] = wdata[23:16];
                    mem[addr[9:0]+3] = wdata[31:24];
                end
                default: ;
            endcase
        end
    end

endmodule
