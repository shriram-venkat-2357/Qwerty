`timescale 1ns/1ps

module tb_pipeline;

    reg clk;
    reg rst_n;
    wire [31:0] pc;

    rv32_pipeline u_cpu (
        .clk    (clk),
        .rst_n  (rst_n),
        .pc_out (pc)
    );

    // Clock: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    initial begin
        $dumpfile("build/pipeline.vcd");
        $dumpvars(0, tb_pipeline);

        rst_n = 0;
        #20;
        rst_n = 1;

        // Run for 400 cycles (more needed due to stalls)
        #4000;

        $display("=== Pipeline Simulation Complete ===");
        $display("Final PC = %h", pc);
        $finish;
    end

    // Monitor every cycle
    integer cycle_count;
    initial cycle_count = 0;

    always @(posedge clk) begin
        if (rst_n) begin
            cycle_count = cycle_count + 1;
            $display("Cycle %0d: PC=%h  Instr=%h  Stall=%b  Flush=%b",
                     cycle_count,
                     u_cpu.pc,
                     u_cpu.instr,
                     u_cpu.if_stall,
                     u_cpu.id_flush);
        end
    end

endmodule
