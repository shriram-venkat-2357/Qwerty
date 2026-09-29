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
    
    // 6-Phase monitoring signals per §4.2

    // Registers to detect rising edges
    reg we_row_q, act_valid_q, busy_q, done_q_q;
    reg [3:0] compute_cycles; // Synthetic counter for §4.2 phases
    
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
            done_q_q    <= done_q; // This line fixes the READBACK spam!

            // Synthetic phase splitting per §4.2
            if (busy && !busy_q) begin
                compute_cycles <= 0;
                $fdisplay(log_file, "Cycle %0d: >>> START CONV", cycle);
            end else if (busy) begin
                compute_cycles <= compute_cycles + 1;
                if (compute_cycles == 1)
                    $fdisplay(log_file, "Cycle %0d: >>> START THRESH", cycle);
                if (compute_cycles == 2)
                    $fdisplay(log_file, "Cycle %0d: >>> START POOL", cycle);
            end else begin
                compute_cycles <= 0;
            end

            if (we_row && !we_row_q)
                $fdisplay(log_file, "Cycle %0d: >>> START WEIGHT_LOAD (LDW)", cycle);
            if (act_valid && !act_valid_q)
                $fdisplay(log_file, "Cycle %0d: >>> START ACT_LOAD (LDA)", cycle);
            if (done_q && !done_q_q)
                $fdisplay(log_file, "Cycle %0d: >>> START READBACK/DONE (RD)", cycle);
        end
    end
endmodule
