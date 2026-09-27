`timescale 1ns/1ps
module tb_trap;
    reg clk, rst_n;
    wire [31:0] pc;

    rv32_pipeline #(.IMEM_FILE("tb/program_trap.hex")) u_cpu (
        .clk(clk), .rst_n(rst_n), .pc_out(pc)
    );

    initial clk = 0;
    always #5 clk = ~clk;
    always @(posedge clk) begin
        if (rst_n && $time < 500)
            $display("t=%0t pc=%h instr=%h mtvec=%h mepc=%h mcause=%h x5=%h",
                     $time, u_cpu.pc, u_cpu.instr,
                     u_cpu.u_csr.mtvec, u_cpu.u_csr.mepc, u_cpu.u_csr.mcause,
                     u_cpu.u_regfile.regs[5]);
    end
    integer errs;
    initial begin
        $dumpfile("build/trap.vcd");
        $dumpvars(0, tb_trap);
        rst_n = 0; #20; rst_n = 1;
        #3000;
        errs = 0;
        if (u_cpu.u_regfile.regs[6] !== 32'd11)  begin errs=errs+1; $display("FAIL mcause: x6=%h", u_cpu.u_regfile.regs[6]); end
        if (u_cpu.u_regfile.regs[7] !== 32'h10)  begin errs=errs+1; $display("FAIL mepc+4: x7=%h", u_cpu.u_regfile.regs[7]); end
        if (u_cpu.u_regfile.regs[8] !== 32'd1)   begin errs=errs+1; $display("FAIL resume-after-mret: x8=%h", u_cpu.u_regfile.regs[8]); end
        if (errs == 0) $display("ALL TRAP TESTS PASSED");
        else $display("%0d trap checks FAILED", errs);
        $finish;
    end
endmodule
