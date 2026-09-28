`timescale 1ns/1ps
module tb_power;
    reg clk, rst_n;
    wire [31:0] pc_out;

    // Standard instantiation
    soc_top u_soc (
        .clk(clk), .rst_n(rst_n), .pc_out(pc_out)
    );

    // 100 MHz clock
    initial clk = 0;
    always #5 clk = ~clk;

    // VCD Dump (full hierarchy for C to analyze)
    initial begin
        $dumpfile("build/power.vcd");
        $dumpvars(0, tb_power);
    end

    integer cycle;
    integer log_file;
    
    // Probe the wires in the parent module (u_core/rv32_pipeline)
    wire we_row   = u_soc.u_core.seq_we_row;
    wire act_valid= u_soc.u_core.seq_act_valid;
    wire busy     = u_soc.u_core.seq_busy;
    wire done_q   = u_soc.u_core.seq_done;

    // Registers to detect rising edges
    reg we_row_q, act_valid_q, busy_q, done_q_q;
    
    initial begin
        cycle = 0;
        rst_n = 0;
        #20;
        rst_n = 1;
        
        log_file = $fopen("build/power_phases.log", "w");
        $fdisplay(log_file, "=== G5 ENERGY TABLE: PHASE TIMESTAMPS (Synthetic Layer) ===");
        $fdisplay(log_file, "NOTE: Functional gate-level sim (no SDF). True timing pending Liberty/SDF from C.");
        $fdisplay(log_file, "Cycle count is based on 100MHz clock (10ns period).");
        $fdisplay(log_file, "-----------------------------------------------------------");
        
        $display("SYNTHETIC_LAYER_START: cycle=%0d", cycle);
        #500000; 
        
        $display("DEBUG: Final pc_out = %h", pc_out);
        $display("DEBUG: Final we_row = %b", we_row);
        $display("DEBUG: Final act_valid = %b", act_valid);
        $display("DEBUG: Final busy = %b", busy);
        $display("DEBUG: Final done_q = %b", done_q);
        
        $fdisplay(log_file, "End of simulation at cycle %0d", cycle);
        $fclose(log_file);
        
        $display("SYNTHETIC_LAYER_END: cycle=%0d", cycle);
        $display("Phase log written to build/power_phases.log");
        $finish;
    end

    always @(posedge clk) begin
        if (rst_n) begin
            cycle <= cycle + 1;
            we_row_q    <= we_row;
            act_valid_q <= act_valid;
            busy_q      <= busy;
            done_q_q    <= done_q;

            if (we_row && !we_row_q)
                $fdisplay(log_file, "Cycle %0d: >>> START WEIGHT_LOAD (LDW)", cycle);
            if (act_valid && !act_valid_q)
                $fdisplay(log_file, "Cycle %0d: >>> START ACT_LOAD (LDA)", cycle);
            if (busy && !busy_q && !we_row && !act_valid)
                $fdisplay(log_file, "Cycle %0d: >>> START COMPUTE (RUN)", cycle);
            if (done_q && !done_q_q)
                $fdisplay(log_file, "Cycle %0d: >>> START READBACK/DONE (RD)", cycle);
        end
    end
endmodule
