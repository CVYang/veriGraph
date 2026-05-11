`timescale 1ns / 1ps

module tb_if_stage;

    // Testbench signals
    reg         clk;
    reg         rst_n;
    reg         stall;
    reg         flush;
    reg         pc_redirect;
    reg  [31:0] pc_target;
    wire [31:0] imem_addr;
    wire        imem_req;
    wire [31:0] if_pc;
    wire [31:0] if_instr;
    wire        if_valid;

    // Instruction memory data (combinational with a small delay to avoid races)
    reg  [31:0] imem_rdata;
    assign #1 imem_rdata = imem_addr;   // real memories have access time

    // Instantiate the design under test
    if_stage dut (
        .clk        (clk),
        .rst_n      (rst_n),
        .stall      (stall),
        .flush      (flush),
        .pc_redirect(pc_redirect),
        .pc_target  (pc_target),
        .imem_addr  (imem_addr),
        .imem_rdata (imem_rdata),
        .imem_req   (imem_req),
        .if_pc      (if_pc),
        .if_instr   (if_instr),
        .if_valid   (if_valid)
    );

    // Clock generation
    initial clk = 1'b0;
    always #5 clk = ~clk;

    // Waveform dumping
    initial begin
        $dumpfile("if_stage_tb.vcd");
        $dumpvars(0, tb_if_stage);
    end

    // Expected (golden) model – mirrors the DUT behaviour
    reg  [31:0] exp_pc;
    reg         exp_imem_req;
    reg  [31:0] exp_if_pc;
    reg  [31:0] exp_if_instr;
    reg         exp_if_valid;

    wire [31:0] exp_pc_next = (!rst_n)       ? 32'h0 :
                              pc_redirect    ? pc_target :
                              stall          ? exp_pc :
                              (exp_pc + 32'h4);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            exp_pc        <= 32'h0;
            exp_imem_req  <= 1'b0;
            exp_if_pc     <= 32'h0;
            exp_if_instr  <= 32'h0;
            exp_if_valid  <= 1'b0;
        end else begin
            exp_pc        <= exp_pc_next;
            exp_imem_req  <= 1'b1;
            if (!stall) begin
                exp_if_pc     <= exp_pc;        // PC value during the cycle
                exp_if_instr  <= exp_pc;        // imem_rdata = imem_addr = pc
                exp_if_valid  <= !flush;
            end
        end
    end

    // Self-checking task
    integer errors = 0;
    task automatic check_outputs;
        begin
            if (dut.imem_addr !== exp_pc) begin
                $display("[%0t] ERROR : imem_addr = %h, expected %h", $time, dut.imem_addr, exp_pc);
                errors++;
            end
            if (dut.imem_req !== exp_imem_req) begin
                $display("[%0t] ERROR : imem_req = %b, expected %b", $time, dut.imem_req, exp_imem_req);
                errors++;
            end
            if (dut.if_pc !== exp_if_pc) begin
                $display("[%0t] ERROR : if_pc = %h, expected %h", $time, dut.if_pc, exp_if_pc);
                errors++;
            end
            if (dut.if_instr !== exp_if_instr) begin
                $display("[%0t] ERROR : if_instr = %h, expected %h", $time, dut.if_instr, exp_if_instr);
                errors++;
            end
            if (dut.if_valid !== exp_if_valid) begin
                $display("[%0t] ERROR : if_valid = %b, expected %b", $time, dut.if_valid, exp_if_valid);
                errors++;
            end
        end
    endtask

    // Main test sequence
    integer test_num = 0;
    initial begin
        // Initialize inputs
        rst_n       = 1'b0;
        stall       = 1'b0;
        flush       = 1'b0;
        pc_redirect = 1'b0;
        pc_target   = 32'h0;

        // Wait a few cycles in reset
        #15;

        // Asynchronous reset check (outputs should be zero)
        test_num++;
        if (dut.imem_addr !== 32'h0 || dut.imem_req !== 1'b0 ||
            dut.if_pc !== 32'h0     || dut.if_instr !== 32'h0 ||
            dut.if_valid !== 1'b0) begin
            $display("[TEST %0d] RESET state FAIL", test_num);
            errors++;
        end else begin
            $display("[TEST %0d] RESET state PASS", test_num);
        end

        // Release reset
        rst_n = 1'b1;
        #1; // small delay before first active edge

        // First clock edge after reset
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] First cycle after reset", test_num);
        check_outputs();

        // Normal operation for 5 cycles
        repeat (5) begin
            @(posedge clk);
            #1;
            test_num++;
            $display("[TEST %0d] Normal cycle", test_num);
            check_outputs();
        end

        // --- Stall test ---
        stall = 1'b1;
        $display("[%0t] Applying stall", $time);
        repeat (3) begin
            @(posedge clk);
            #1;
            test_num++;
            $display("[TEST %0d] Stall cycle", test_num);
            check_outputs();
        end

        // Release stall
        stall = 1'b0;
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] After stall release", test_num);
        check_outputs();

        // One normal cycle after stall
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Normal after stall", test_num);
        check_outputs();

        // --- Redirect test (without stall) ---
        pc_redirect = 1'b1;
        pc_target   = 32'h100;
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Redirect to 0x100", test_num);
        check_outputs();          // PC becomes 0x100, IF outputs hold old values

        // Fetch from new PC
        pc_redirect = 1'b0;
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Fetch from 0x100", test_num);
        check_outputs();          // IF outputs reflect PC=0x100

        // --- Flush test ---
        flush = 1'b1;
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Flush cycle 1", test_num);
        check_outputs();          // if_valid = 0, others update normally

        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Flush cycle 2", test_num);
        check_outputs();

        flush = 1'b0;
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Flush released", test_num);
        check_outputs();          // if_valid = 1 again

        // --- Redirect during stall (priority test) ---
        stall       = 1'b1;
        pc_redirect = 1'b1;
        pc_target   = 32'h200;
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Stall+Redirect (PC to 0x200, outputs hold)", test_num);
        check_outputs();          // PC becomes 0x200, IF outputs unchanged

        // Keep stall, remove redirect
        pc_redirect = 1'b0;
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Stall only, PC holds 0x200", test_num);
        check_outputs();

        // Release stall – now outputs update to PC=0x200
        stall = 1'b0;
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Stall released after redirect, fetch from 0x200", test_num);
        check_outputs();

        // --- Flush + stall interaction ---
        stall = 1'b1;
        flush = 1'b1;
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Flush+Stall (outputs hold)", test_num);
        check_outputs();          // outputs unchanged (if_valid still 1)

        // Release stall while flush still high
        stall = 1'b0;
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Stall released, flush high (if_valid=0)", test_num);
        check_outputs();          // if_valid goes to 0

        flush = 1'b0;
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Flush released (if_valid=1)", test_num);
        check_outputs();

        // --- Asynchronous reset during normal operation ---
        rst_n = 1'b0;
        #12;  // let the reset propagate
        test_num++;
        if (dut.imem_addr !== 32'h0 || dut.imem_req !== 1'b0 ||
            dut.if_pc !== 32'h0     || dut.if_instr !== 32'h0 ||
            dut.if_valid !== 1'b0) begin
            $display("[TEST %0d] Async reset FAIL", test_num);
            errors++;
        end else begin
            $display("[TEST %0d] Async reset PASS", test_num);
        end

        // Recover from reset
        rst_n = 1'b1;
        @(posedge clk);
        #1;
        test_num++;
        $display("[TEST %0d] Recovery after async reset", test_num);
        check_outputs();

        // Final result
        if (errors == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED with %0d errors", errors);

        $finish;
    end

endmodule