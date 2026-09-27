module imem #(
    parameter FILE = "program.hex"
)(
    input  wire [31:0] addr,
    output wire [31:0] instr
);
    // 256 words of instruction memory
    reg [31:0] mem [0:4095];

    // Read instruction (combinational)
    assign instr = mem[addr[13:2]];

    // Initialize memory from file
    initial begin
        $readmemh(FILE, mem);
    end
endmodule
