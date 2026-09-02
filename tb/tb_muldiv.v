`timescale 1ns/1ps
module tb_muldiv;
    reg  [31:0] a, b;
    reg  [2:0]  f3;
    wire [31:0] r;

    muldiv u (.a(a), .b(b), .funct3(f3), .result(r));

    integer errs;
    initial begin
        errs = 0;

        a = 7;  b = 3;  f3 = 0; #1;  // MUL
        if (r !== 21) begin errs = errs+1; $display("FAIL mul"); end

        a = 32'hFFFF_FFF9; b = 3; f3 = 1; #1;  // MULH (-7*3 = -21, upper = -1)
        if (r !== 32'hFFFF_FFFF) begin errs = errs+1; $display("FAIL mulh"); end

        a = 32'hFFFF_FFFF; b = 32'hFFFF_FFFF; f3 = 3; #1;  // MULHU
        if (r !== 32'hFFFF_FFFE) begin errs = errs+1; $display("FAIL mulhu"); end

        a = 10; b = 3; f3 = 4; #1;  // DIV
        if (r !== 3) begin errs = errs+1; $display("FAIL div"); end

        a = 10; b = 3; f3 = 6; #1;  // REM
        if (r !== 1) begin errs = errs+1; $display("FAIL rem"); end

        a = 10; b = 0; f3 = 4; #1;  // DIV by zero -> -1
        if (r !== 32'hFFFF_FFFF) begin errs = errs+1; $display("FAIL div0"); end

        a = 10; b = 0; f3 = 6; #1;  // REM by zero -> dividend
        if (r !== 10) begin errs = errs+1; $display("FAIL rem0"); end

        a = 32'h8000_0000; b = 32'hFFFF_FFFF; f3 = 4; #1;  // overflow DIV -> MIN
        if (r !== 32'h8000_0000) begin errs = errs+1; $display("FAIL divovf"); end

        a = 32'h8000_0000; b = 32'hFFFF_FFFF; f3 = 6; #1;  // overflow REM -> 0
        if (r !== 0) begin errs = errs+1; $display("FAIL removf"); end

        if (errs == 0) $display("ALL MULDIV TESTS PASSED");
        else $display("%0d muldiv tests FAILED", errs);
        $finish;
    end
endmodule
