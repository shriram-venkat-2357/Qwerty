`timescale 1ns/1ps
module tb_dbg2;
    reg clk, rst_n;
    wire [31:0] pc;
    rv32_pipeline #(.IMEM_FILE("tb/program_nmc.hex")) u_cpu (
        .clk(clk), .rst_n(rst_n), .pc_out(pc)
    );
    initial clk = 0;
    always #5 clk = ~clk;
    integer c;
    always @(posedge clk) begin
        c <= c + 1;
        if (c < 60)
            $display("c=%0d pc=%h idop=%h wait=%b istall=%b idfl=%b issue=%b seqst=%0d busy=%b fcnt=%0d cnt=%0d",
                c, pc, u_cpu.id_opcode, u_cpu.nmc_wait, u_cpu.if_stall, u_cpu.id_flush,
                u_cpu.nmc_issue, u_cpu.u_seq.state, u_cpu.u_seq.busy,
                u_cpu.u_seq.fcnt, u_cpu.u_seq.cnt);
    end
    initial begin c = 0; rst_n = 0; #20; rst_n = 1; #4000; $finish; end
endmodule
