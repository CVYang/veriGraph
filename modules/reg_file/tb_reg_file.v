`timescale 1ns/1ps

module tb_reg_file;

    // DUT signals
    reg clk;
    reg rst_n;
    reg [4:0] rs1_addr;
    reg [4:0] rs2_addr;
    wire [31:0] rs1_data;
    wire [31:0] rs2_data;
    reg [4:0] waddr;
    reg [31:0] wdata;
    reg we;

    // Test control
    integer errors;
    reg [31:0] expected_rs1;
    reg [31:0] expected_rs2;

    // Instantiate DUT
    reg_file uut (
        .clk(clk),
        .rst_n(rst_n),
        .rs1_addr(rs1_addr),
        .rs2_addr(rs2_addr),
        .rs1_data(rs1_data),
        .rs2_data(rs2_data),
        .waddr(waddr),
        .wdata(wdata),
        .we(we)
    );

    // Clock generation (10ns period)
    initial clk = 0;
    always #5 clk = ~clk;

    // Self-checking task
    task check_output;
        input [31:0] exp_rs1;
        input [31:0] exp_rs2;
        input [8*30:1] msg;
        begin
            if (rs1_data !== exp_rs1) begin
                $display("[ERROR] %s: rs1_data = 0x%h, expected = 0x%h", msg, rs1_data, exp_rs1);
                errors = errors + 1;
            end
            if (rs2_data !== exp_rs2) begin
                $display("[ERROR] %s: rs2_data = 0x%h, expected = 0x%h", msg, rs2_data, exp_rs2);
                errors = errors + 1;
            end
        end
    endtask

    initial begin
        // Enable waveform dump
        $dumpfile("reg_file_tb.vcd");
        $dumpvars(0, tb_reg_file);

        errors = 0;
        $display("============================================");
        $display("  Register File Testbench Started");
        $display("============================================");

        // Initialize inputs
        rst_n = 1;
        rs1_addr = 5'd0;
        rs2_addr = 5'd0;
        waddr = 5'd0;
        wdata = 32'h0;
        we = 1'b0;

        // ---------- RESET ----------
        $display("[TEST] Applying reset...");
        rst_n = 1'b1;
        #2 rst_n = 1'b0;
        #10; // wait a clock cycle
        rst_n = 1'b0;
        #10 rst_n = 1'b1;
        #1; // allow propagation

        // After reset all registers (x1..x31) must be zero, x0 = 0 by definition
        $display("[CHECK] Post-reset reads (all zeros)");
        rs1_addr = 5'd0;  rs2_addr = 5'd0;  #1;
        check_output(32'h0, 32'h0, "x0, x0 after reset");
        rs1_addr = 5'd1;  rs2_addr = 5'd2;  #1;
        check_output(32'h0, 32'h0, "x1, x2 after reset");
        rs1_addr = 5'd31; rs2_addr = 5'd10; #1;
        check_output(32'h0, 32'h0, "x31, x10 after reset");

        // ---------- TEST 1: x0 always zero and write to x0 ignored ----------
        $display("[TEST] x0 is hardwired to zero, writing to x0 should be ignored");
        // Attempt to write 0xDEADBEEF to x0
        @(negedge clk); // synchronize to clock edge
        we = 1; waddr = 5'd0; wdata = 32'hDEAD_BEEF;
        rs1_addr = 5'd0; rs2_addr = 5'd1;
        #1; // async read during write request
        check_output(32'h0, 32'h0, "x0 must be zero during write to x0, x1 unchanged");
        @(posedge clk); // actual write edge
        #1; // after write
        check_output(32'h0, 32'h0, "x0 still zero after write attempt, x1 unchanged");
        we = 0; #1;
        // Now read x0 and x1 again without forwarding
        rs1_addr = 5'd0; rs2_addr = 5'd1; #1;
        check_output(32'h0, 32'h0, "x0 remains 0, x1 remains 0 after illegal write");

        // ---------- TEST 2: Normal write and read back ----------
        $display("[TEST] Normal write to x1 and read back");
        @(negedge clk);
        we = 1; waddr = 5'd1; wdata = 32'hAAAA_5555;
        rs1_addr = 5'd1; rs2_addr = 5'd2;
        #1; // forwarding: rs1 should see wdata, rs2 remains zero
        check_output(32'hAAAA_5555, 32'h0, "write x1: forwarding to rs1");
        @(posedge clk);
        #1;
        we = 0; 
        // Now read after write (forwarding disabled)
        rs1_addr = 5'd1; rs2_addr = 5'd0; #1;
        check_output(32'hAAAA_5555, 32'h0, "x1 holds 0xAAAA_5555, x0 is 0");

        // ---------- TEST 3: Write to another register and read multiple ----------
        $display("[TEST] Write x2 with 0x1234_5678, verify x1 unchanged");
        @(negedge clk);
        we = 1; waddr = 5'd2; wdata = 32'h1234_5678;
        rs1_addr = 5'd1; rs2_addr = 5'd2;
        #1;
        check_output(32'hAAAA_5555, 32'h1234_5678, "write x2: x1 unchanged, x2 forwarding");
        @(posedge clk);
        #1;
        we = 0;
        rs1_addr = 5'd1; rs2_addr = 5'd2; #1;
        check_output(32'hAAAA_5555, 32'h1234_5678, "after write x2, values hold");

        // ---------- TEST 4: Write during read of different address ----------
        $display("[TEST] Write x3 while reading x4 (no forwarding)");
        @(negedge clk);
        we = 1; waddr = 5'd3; wdata = 32'hF0F0_F0F0;
        rs1_addr = 5'd4; rs2_addr = 5'd3; // rs2 sees same address -> forwarding expected
        #1;
        check_output(32'h0, 32'hF0F0_F0F0, "write x3: x4 should be 0, x3 forwarding");
        @(posedge clk);
        #1;
        we = 0;
        rs1_addr = 5'd3; rs2_addr = 5'd4; #1;
        check_output(32'hF0F0_F0F0, 32'h0, "x3 stored, x4 still zero");

        // ---------- TEST 5: Write enable = 0, no write should occur ----------
        $display("[TEST] Write with we=0 should not change register");
        @(negedge clk);
        we = 0; waddr = 5'd1; wdata = 32'hDEAD_C0DE;
        rs1_addr = 5'd1; #1;
        check_output(32'hAAAA_5555, 32'hAAAA_5555, "before we=0 write attempt, x1 holds old value");
        @(posedge clk);
        #1;
        check_output(32'hAAAA_5555, 32'hAAAA_5555, "after we=0 write, x1 unchanged");

        // ---------- TEST 6: Write multiple registers and verify no cross-talk ----------
        $display("[TEST] Write to x10=0x10, x11=0x11, x12=0x12");
        @(negedge clk);
        we = 1; waddr = 5'd10; wdata = 32'h10; #1;
        @(posedge clk);
        @(negedge clk);
        we = 1; waddr = 5'd11; wdata = 32'h11; #1;
        @(posedge clk);
        @(negedge clk);
        we = 1; waddr = 5'd12; wdata = 32'h12; #1;
        @(posedge clk);
        we = 0;
        rs1_addr = 5'd10; rs2_addr = 5'd11; #1;
        check_output(32'h10, 32'h11, "read x10, x11");
        rs1_addr = 5'd12; rs2_addr = 5'd1; #1;
        check_output(32'h12, 32'hAAAA_5555, "read x12, x1 still intact");

        // ---------- TEST 7: Asynchronous read change test ----------
        $display("[TEST] Asynchronous read: changing address should reflect stored data immediately");
        rs1_addr = 5'd10; rs2_addr = 5'd12; #1;
        check_output(32'h10, 32'h12, "read x10, x12");
        rs1_addr = 5'd11; rs2_addr = 5'd0; #1;
        check_output(32'h11, 32'h0, "switch to x11, x0");

        // ---------- TEST 8: Read during reset (asynchronous) ----------
        $display("[TEST] Read during active low reset");
        rst_n = 1'b0; #1;
        // All registers should be zero due to reset
        rs1_addr = 5'd1; rs2_addr = 5'd12; #1;
        check_output(32'h0, 32'h0, "during reset, all registers zero");
        rst_n = 1'b1; #10; // release reset
        // After reset release, all previous values are gone
        rs1_addr = 5'd1; #1;
        check_output(32'h0, 32'h0, "after reset release, registers cleared");

        // Re-write a value to test normal operation after reset
        @(negedge clk);
        we = 1; waddr = 5'd5; wdata = 32'h5555_AAAA;
        rs1_addr = 5'd5; #1;
        @(posedge clk);
        we = 0; #1;
        rs1_addr = 5'd5; #1;
        check_output(32'h5555_AAAA, 32'h5555_AAAA, "write after reset");

        // ---------- FINAL REPORT ----------
        if (errors == 0) begin
            $display("============================================");
            $display("  TEST PASSED: No errors found.");
            $display("============================================");
        end else begin
            $display("============================================");
            $display("  TEST FAILED: %0d error(s) detected.", errors);
            $display("============================================");
        end

        $finish;
    end

endmodule