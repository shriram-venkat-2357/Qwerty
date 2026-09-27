`timescale 1ns/1ps
module tb_nmc_instr;
    reg clk, rst_n;
    wire [31:0] pc;

    rv32_pipeline #(.IMEM_FILE("tb/program_nmc.hex")) u_cpu (
        .clk(clk), .rst_n(rst_n), .pc_out(pc)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer errs;
    initial begin
        errs = 0;
        rst_n = 0; #20; rst_n = 1;
        #20000;   // 2000 cycles — plenty for 23 instructions + accelerator ops

        // ldw moved 4 all-ones words from dmem into weight rows 0..3
        if (u_cpu.u_nmc.wmem[0*32 +: 32] !== 32'hFFFFFFFF ||
            u_cpu.u_nmc.wmem[3*32 +: 32] !== 32'hFFFFFFFF) begin
            errs = errs+1; $display("FAIL weights: %h %h",
                u_cpu.u_nmc.wmem[0*32 +: 32], u_cpu.u_nmc.wmem[3*32 +: 32]); end

        // run streamed 2 all-ones activation vectors: dot=+128 each,
        // clr on pos0 then accumulate on pos1 -> 256 in every column
        if (u_cpu.u_nmc.u_psum.acc[0*32 +: 32]  !== 32'd256 ||
            u_cpu.u_nmc.u_psum.acc[31*32 +: 32] !== 32'd256) begin
            errs = errs+1; $display("FAIL acc: %0d", u_cpu.u_nmc.u_psum.acc[0*32 +: 32]); end

        // rd x6 returned the (zero) result register — proves rd executed
        if (u_cpu.u_regfile.regs[6] !== 32'd0) begin
            errs = errs+1; $display("FAIL rd: %h", u_cpu.u_regfile.regs[6]); end

        // csrr x7 saw ready=1,done=1,error=0,busy=0 -> 0xA
        // (also proves rd stalled until run finished: otherwise busy=1 here)
        if (u_cpu.u_regfile.regs[7] !== 32'hA) begin
            errs = errs+1; $display("FAIL status: %h", u_cpu.u_regfile.regs[7]); end

        if (errs == 0) $display("ALL NMC INSTR TESTS PASSED");
        else $display("%0d nmc-instr checks FAILED", errs);
        $finish;
    end
endmodule
