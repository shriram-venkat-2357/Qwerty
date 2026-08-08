`timescale 1ns/1ps

module tb_fetch_decode_stub;

    reg clk;
    reg rst_n;

    wire [31:0] pc;
    wire [31:0] instr;
    wire [6:0]  opcode;

    rv32_fetch_decode_stub dut (
        .clk    (clk),
        .rst_n  (rst_n),
        .pc     (pc),
        .instr  (instr),
        .opcode (opcode)
    );

    initial begin
        clk = 0;
    end

    always begin
        #5 clk = ~clk;
    end

    initial begin
        $dumpfile("build/fetch_decode_stub.vcd");
        $dumpvars(0, tb_fetch_decode_stub);

        rst_n = 0;

        #20;
        rst_n = 1;

        #100;

        $display("Simulation finished.");
        $display("PC = %h", pc);
        $display("Instruction = %h", instr);
        $display("Opcode = %b", opcode);

        $finish;
    end

endmodule
