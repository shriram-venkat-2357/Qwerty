`timescale 1ns/1ps

module tb_single_cycle;

    reg clk;
    reg rst_n;
    wire [31:0] pc;

    // Instantiate the CPU
    rv32_single_cycle u_cpu (
        .clk    (clk),
        .rst_n  (rst_n),
        .pc_out (pc)
    );

    // Clock generation: 10ns period (100 MHz)
    initial begin
        clk = 0;
    end

    always begin
        #5 clk = ~clk;
    end

    // Reset and run
    initial begin
        $dumpfile("build/single_cycle.vcd");
        $dumpvars(0, tb_single_cycle);

        // Apply reset
        rst_n = 0;
        #20;
        rst_n = 1;

        // Run for 200 cycles
        #2000;

        $display("=== Simulation Complete ===");
        $display("Final PC = %h", pc);
        $finish;
    end

    // Monitor key signals every cycle
    always @(posedge clk) begin
        if (rst_n) begin
            $display("Cycle: PC=%h  Instr=%h  RegWrite=%b  RD=%d  WriteData=%h",
                     u_cpu.pc,
                     u_cpu.instr,
                     u_cpu.reg_write,
                     u_cpu.rd,
                     u_cpu.write_data);
        end
    end

endmodule
