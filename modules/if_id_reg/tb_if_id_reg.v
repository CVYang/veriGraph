`timescale 1ns/1ps

module tb_if_id_reg;
    reg clk;
    reg rst_n;
    reg flush;
    reg stall;
    reg [31:0] if_pc;
    reg [31:0] if_instr;
    reg if_valid;

    wire [31:0] id_pc;
    wire [31:0] id_instr;
    wire id_valid;

    // Instantiate DUT
    if_id_reg dut (
        .clk(clk),
        .rst_n(rst_n),
        .flush(flush),
        .stall(stall),
        .if_pc(if_pc),
        .if_instr(if_instr),
        .if_valid(if_valid),
        .id_pc(id_pc),
        .id_instr(id_instr),
        .id_valid(id_valid)
    );

    // Clock generation (10 ns period)
    always #5 clk = ~clk;

    integer error_count;

    // Task to apply inputs, wait one clock cycle, and verify outputs
    task apply_and_check;
        input [31:0] pc_in;
        input [31:0] instr_in;
        input valid_in;
        input f_in;
        input s_in;
        input [31:0] exp_pc;
        input [31:0] exp_instr;
        input exp_valid;
        input string test_name;
        begin
            if_pc = pc_in;
            if_instr = instr_in;
            if_valid = valid_in;
            flush = f_in;
            stall = s_in;
            @(posedge clk);
            #1; // small delay for output propagation
            if (id_pc !== exp_pc || id_instr !== exp_instr || id_valid !== exp_valid) begin
                $display("ERROR [%s]: Expected pc=%h instr=%h valid=%b, Got pc=%h instr=%h valid=%b",
                         test_name, exp_pc, exp_instr, exp_valid, id_pc, id_instr, id_valid);
                error_count = error_count + 1;
            end else begin
                $display("PASS  [%s]: pc=%h instr=%h valid=%b", test_name, id_pc, id_instr, id_valid);
            end
        end
    endtask

    initial begin
        // Waveform dump
        $dumpfile("if_id_reg_tb.vcd");
        $dumpvars(0, tb_if_id_reg);

        error_count = 0;

        // Initialize signals
        clk   = 0;
        rst_n = 0;
        flush = 0;
        stall = 0;
        if_pc    = 32'hDEADBEEF;
        if_instr = 32'hCAFEBABE;
        if_valid = 1'b1;

        // Apply reset for a couple of cycles
        repeat(2) @(posedge clk);
        #1;
        // After reset, outputs must be zero
        if (id_pc !== 32'h0 || id_instr !== 32'h0 || id_valid !== 1'b0) begin
            $display("ERROR [Reset]: Expected 0 after reset, Got pc=%h instr=%h valid=%b", id_pc, id_instr, id_valid);
            error_count = error_count + 1;
        end else begin
            $display("PASS  [Reset]: Outputs zero after reset");
        end

        // Release reset and test normal transfer
        rst_n = 1;
        if_pc    = 32'h1111_1111;
        if_instr = 32'h2222_2222;
        if_valid = 1'b1;
        flush    = 0;
        stall    = 0;
        @(posedge clk);
        #1;
        if (id_pc !== 32'h1111_1111 || id_instr !== 32'h2222_2222 || id_valid !== 1'b1) begin
            $display("ERROR [Normal1]: Expected 1111_1111 2222_2222 1, Got %h %h %b", id_pc, id_instr, id_valid);
            error_count = error_count + 1;
        end else $display("PASS  [Normal1]");

        // Normal operation with different values
        apply_and_check(32'h3333_3333, 32'h4444_4444, 1'b1, 1'b0, 1'b0, 32'h3333_3333, 32'h4444_4444, 1'b1, "Normal2");

        // Valid = 0 transfer
        apply_and_check(32'h5555_5555, 32'h6666_6666, 1'b0, 1'b0, 1'b0, 32'h5555_5555, 32'h6666_6666, 1'b0, "Valid0");

        // Stall test: outputs must hold previous value
        apply_and_check(32'hAAAA_AAAA, 32'hBBBB_BBBB, 1'b1, 1'b0, 1'b0, 32'hAAAA_AAAA, 32'hBBBB_BBBB, 1'b1, "PreStall");
        // Activate stall, change inputs
        stall    = 1;
        if_pc    = 32'hCCCC_CCCC;
        if_instr = 32'hDDDD_DDDD;
        if_valid = 1'b0;
        @(posedge clk);
        #1;
        if (id_pc !== 32'hAAAA_AAAA || id_instr !== 32'hBBBB_BBBB || id_valid !== 1'b1) begin
            $display("ERROR [Stall]: Expected hold AAAA_AAAA BBBB_BBBB 1, Got %h %h %b", id_pc, id_instr, id_valid);
            error_count = error_count + 1;
        end else $display("PASS  [Stall]");
        // Release stall, next cycle should capture the new inputs
        stall = 0;
        apply_and_check(if_pc, if_instr, if_valid, flush, stall, 32'hCCCC_CCCC, 32'hDDDD_DDDD, 1'b0, "AfterStall");

        // Flush test
        apply_and_check(32'hF0F0_F0F0, 32'h0F0F_0F0F, 1'b1, 1'b0, 1'b0, 32'hF0F0_F0F0, 32'h0F0F_0F0F, 1'b1, "PreFlush");
        flush    = 1;
        if_pc    = 32'hDEAD_DEAD;
        if_instr = 32'hBEEF_BEEF;
        if_valid = 1'b1;
        @(posedge clk);
        #1;
        if (id_pc !== 32'h0 || id_instr !== 32'h0 || id_valid !== 1'b0) begin
            $display("ERROR [Flush]: Expected all zeros, Got %h %h %b", id_pc, id_instr, id_valid);
            error_count = error_count + 1;
        end else $display("PASS  [Flush]");
        // After flush, remove flush signal and check normal capture
        flush = 0;
        apply_and_check(if_pc, if_instr, if_valid, flush, stall, 32'hDEAD_DEAD, 32'hBEEF_BEEF, 1'b1, "AfterFlush");

        // Priority: flush over stall
        apply_and_check(32'h1234_5678, 32'h9ABC_DEF0, 1'b1, 1'b0, 1'b0, 32'h1234_5678, 32'h9ABC_DEF0, 1'b1, "PreFlushStall");
        flush = 1;
        stall = 1;
        if_pc    = 32'hFFFF_FFFF;
        if_instr = 32'h0000_0000;
        if_valid = 1'b1;
        @(posedge clk);
        #1;
        if (id_pc !== 32'h0 || id_instr !== 32'h0 || id_valid !== 1'b0) begin
            $display("ERROR [FlushOverStall]: Expected zeros, Got %h %h %b", id_pc, id_instr, id_valid);
            error_count = error_count + 1;
        end else $display("PASS  [FlushOverStall]");
        flush = 0;
        stall = 0;
        apply_and_check(if_pc, if_instr, if_valid, flush, stall, 32'hFFFF_FFFF, 32'h0000_0000, 1'b1, "AfterFlushStall");

        // Stall for multiple cycles
        apply_and_check(32'hCAFE_CAFE, 32'hFACE_FACE, 1'b1, 1'b0, 1'b0, 32'hCAFE_CAFE, 32'hFACE_FACE, 1'b1, "PreStallMulti");
        stall = 1;
        if_pc    = 32'h1111_2222;
        if_instr = 32'h3333_4444;
        if_valid = 1'b0;
        @(posedge clk);
        #1;
        if (id_pc !== 32'hCAFE_CAFE || id_instr !== 32'hFACE_FACE || id_valid !== 1'b1) begin
            $display("ERROR [StallMulti1]");
            error_count = error_count + 1;
        end else $display("PASS  [StallMulti1]");
        // Change inputs again while still stalled
        if_pc    = 32'h5555_6666;
        if_instr = 32'h7777_8888;
        if_valid = 1'b1;
        @(posedge clk);
        #1;
        if (id_pc !== 32'hCAFE_CAFE || id_instr !== 32'hFACE_FACE || id_valid !== 1'b1) begin
            $display("ERROR [StallMulti2]");
            error_count = error_count + 1;
        end else $display("PASS  [StallMulti2]");
        // Release stall and check capture of latest inputs
        stall = 0;
        apply_and_check(if_pc, if_instr, if_valid, flush, stall, 32'h5555_6666, 32'h7777_8888, 1'b1, "AfterStallMulti");

        // Re-test reset during normal operation
        apply_and_check(32'hABC_1234, 32'hDEF_5678, 1'b1, 1'b0, 1'b0, 32'hABC_1234, 32'hDEF_5678, 1'b1, "PreResetAgain");
        rst_n = 0;
        if_pc    = 32'hFFFF_FFFF;
        if_instr = 32'hFFFF_FFFF;
        if_valid = 1'b1;
        @(posedge clk);
        #1;
        if (id_pc !== 32'h0 || id_instr !== 32'h0 || id_valid !== 1'b0) begin
            $display("ERROR [ResetAgain]: Expected zeros, Got %h %h %b", id_pc, id_instr, id_valid);
            error_count = error_count + 1;
        end else $display("PASS  [ResetAgain]");

        // Final report
        if (error_count == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED with %0d errors", error_count);

        $finish;
    end
endmodule