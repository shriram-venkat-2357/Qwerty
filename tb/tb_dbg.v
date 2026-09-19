`timescale 1ns/1ps
module tb_dbg;
    reg clk, rst_n;
    wire [31:0] pc;

    rv32_pipeline #(.IMEM_FILE("tb/program_nmc.hex")) u_cpu (
        .clk(clk), .rst_n(rst_n), .pc_out(pc)
    );

    initial clk = 0;
    always #5 clk = ~clk;

    integer cyc;
    always @(posedge clk) begin
        cyc <= cyc + 1;
        if (cyc < 80) begin
            if (u_cpu.u_dmem.mem_write)
                $display("c=%0d DMEM_WR addr=%0h data=%h", cyc, u_cpu.u_dmem.addr, u_cpu.u_dmem.wdata);
            if (u_cpu.u_seq.we_row)
                $display("c=%0d SEQ_WE row=%0d data=%h baddr=%0h", cyc, u_cpu.u_seq.wr_row, u_cpu.u_seq.wr_data, u_cpu.u_seq.b_addr);
            if (u_cpu.u_seq.act_valid)
                $display("c=%0d ACT %h", cyc, u_cpu.u_seq.act_out);
        end
    end

    initial begin
        cyc = 0; rst_n = 0; #20; rst_n = 1;
        #20000;
        $display("wmem: %h %h %h %h", u_cpu.u_nmc.wmem[0], u_cpu.u_nmc.wmem[1],
                 u_cpu.u_nmc.wmem[2], u_cpu.u_nmc.wmem[3]);
        $display("dmem w0=%h w3=%h w4=%h w11=%h",
            {u_cpu.u_dmem.mem[3],  u_cpu.u_dmem.mem[2],  u_cpu.u_dmem.mem[1],  u_cpu.u_dmem.mem[0]},
            {u_cpu.u_dmem.mem[15], u_cpu.u_dmem.mem[14], u_cpu.u_dmem.mem[13], u_cpu.u_dmem.mem[12]},
            {u_cpu.u_dmem.mem[19], u_cpu.u_dmem.mem[18], u_cpu.u_dmem.mem[17], u_cpu.u_dmem.mem[16]},
            {u_cpu.u_dmem.mem[47], u_cpu.u_dmem.mem[46], u_cpu.u_dmem.mem[45], u_cpu.u_dmem.mem[44]});
        $display("regs: x1=%h x2=%h x4=%h x5=%h x7=%h",
            u_cpu.u_regfile.regs[1], u_cpu.u_regfile.regs[2], u_cpu.u_regfile.regs[4],
            u_cpu.u_regfile.regs[5], u_cpu.u_regfile.regs[7]);
        $finish;
    end
endmodule
