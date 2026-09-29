`timescale 1ns/1ps
module tb_e2e;
    reg clk, rst_n;
    wire [31:0] pc;

    rv32_pipeline #(.IMEM_FILE("tb/program_e2e.hex")) u_cpu (
        .clk(clk), .rst_n(rst_n), .pc_out(pc)
    );


    // --- Decision 0002 sampler: latch the one-cycle nmc.cfg write pulse ---
    reg saw_cfg300 = 1'b0, saw_cfg0 = 1'b0;
    always @(posedge clk) begin
        if (u_cpu.u_nmc.we_thr === 1'b1 && u_cpu.u_nmc.thr_addr === 5'd0 && u_cpu.u_nmc.thr_data === 32'd300) saw_cfg300 <= 1'b1;
        if (u_cpu.u_nmc.we_thr === 1'b1 && u_cpu.u_nmc.thr_addr === 5'd0 && u_cpu.u_nmc.thr_data === 32'd0)  saw_cfg0  <= 1'b1;
    end
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

    if (saw_cfg300) $display("CFG TEST PASSED: nmc.cfg wrote thr[0]=300");
    else begin $display("CFG TEST FAILED: thr[0]=300 write never observed"); $finish; end
    if (saw_cfg0)  $display("CFG TEST PASSED: nmc.cfg restored thr[0]=0");
    else begin $display("CFG TEST FAILED: thr[0]=0 restore never observed"); $finish; end
        if (errs == 0) $display("ALL NMC INSTR TESTS PASSED");
        else $display("%0d nmc-instr checks FAILED", errs);
        $finish;
    end

    // ---- D8 backdoor staging + provisional golden diff (sim-only) ----
    reg [31:0] e2e_tmp [0:127];
    integer bi;
    initial begin
        $readmemh("training/export/weights.hex", e2e_tmp);
        for (bi = 0; bi < 39; bi++) begin
            u_cpu.u_dmem.mem[0 + bi*4 + 0] = e2e_tmp[bi][7:0];
            u_cpu.u_dmem.mem[0 + bi*4 + 1] = e2e_tmp[bi][15:8];
            u_cpu.u_dmem.mem[0 + bi*4 + 2] = e2e_tmp[bi][23:16];
            u_cpu.u_dmem.mem[0 + bi*4 + 3] = e2e_tmp[bi][31:24];
        end
        $readmemh("tb/act_e2e.hex", e2e_tmp);
        for (bi = 0; bi < 16; bi++) begin
            u_cpu.u_dmem.mem[256 + bi*4 + 0] = e2e_tmp[bi][7:0];
            u_cpu.u_dmem.mem[256 + bi*4 + 1] = e2e_tmp[bi][15:8];
            u_cpu.u_dmem.mem[256 + bi*4 + 2] = e2e_tmp[bi][23:16];
            u_cpu.u_dmem.mem[256 + bi*4 + 3] = e2e_tmp[bi][31:24];
        end
    end
    initial begin : e2e_watch
        integer tc; reg [31:0] magic, got;
        for (tc = 0; tc < 4_000_000; tc = tc + 1) begin
            @(posedge clk);
            magic = {u_cpu.u_dmem.mem[803], u_cpu.u_dmem.mem[802],
                     u_cpu.u_dmem.mem[801], u_cpu.u_dmem.mem[800]};
            if (magic === 32'hCAFEF00D) begin
                got = {u_cpu.u_dmem.mem[771], u_cpu.u_dmem.mem[770],
                       u_cpu.u_dmem.mem[769], u_cpu.u_dmem.mem[768]};
                // PROVISIONAL: golden.txt semantics (class label vs raw word)
                // to be confirmed by C; print both sides either way.
                $display("D8 RESULT: e2e rd word = %08x ; golden.txt = 00000007", got);
                $finish;
            end
        end
        $display("D8 TIMEOUT: driver never posted done magic");
        $finish;
    end
endmodule
