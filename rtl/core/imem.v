module imem (
    input  wire [31:0] addr,
    output wire [31:0] instr
);

    // 256 words of instruction memory
    reg [31:0] mem [0:255];

    // Read instruction (combinational)
    assign instr = mem[addr[31:2]];

    // Initialize memory from file
    initial begin
        $readmemh("program.hex", mem);
    end

endmodule
