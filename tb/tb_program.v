`timescale 1ns/1ps

module tb_program;
    parameter IMEM_FILE = "program.hex";
    parameter TIMEOUT   = 100000;
    parameter [31:0] TOHOST = 32'h0000_07F0;

    reg         clk   = 1'b0;
    reg         rst_n = 1'b0;
    wire [31:0] pc_out;

    always #5 clk = ~clk;

    rv32_pipeline #(.IMEM_FILE(IMEM_FILE)) dut (
        .clk   (clk),
        .rst_n (rst_n),
        .pc_out(pc_out)
    );

    wire        st_en   = dut.mem_mem_write && (dut.mem_funct3 == 3'b010);
    wire [31:0] st_addr = dut.mem_alu_result;
    wire [31:0] st_data = dut.mem_rs2_data;

    integer cycles = 0;

    initial begin
        $dumpfile("tb_program.vcd");
        $dumpvars(0, tb_program);
        repeat (5) @(posedge clk);
        @(negedge clk) rst_n = 1'b1;
    end

    always @(posedge clk) if (rst_n) begin
        cycles <= cycles + 1;
        if (st_en && st_addr == TOHOST) begin
            if (st_data == 32'd1) $display("PASS  (%0d cycles)", cycles);
            else $display("FAIL  code=%0d  PC=%h  (%0d cycles)", st_data, pc_out, cycles);
            $finish;
        end
        if (cycles >= TIMEOUT) begin
            $display("TIMEOUT after %0d cycles, PC=%h", cycles, pc_out);
            $finish;
        end
    end
endmodule
