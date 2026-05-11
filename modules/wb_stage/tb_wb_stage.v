`timescale 1ns/1ps

module tb_wb_stage;

    // Clock and reset
    reg clk;
    reg rst_n;

    // DUT inputs
    reg [31:0]  wb_mem_rdata;
    reg [31:0]  wb_alu_result;
    reg [31:0]  wb_pc_plus4;
    reg [4:0]   wb_rd_addr;
    reg         wb_reg_write;
    reg [1:0]   wb_wb_sel;
    reg         wb_valid;

    // DUT outputs
    wire [4:0]  rf_waddr;
    wire [31:0] rf_wdata;
    wire        rf_we;
    wire [31:0] wb_result;

    integer mismatch_count = 0;
    integer test_num = 0;

    // Instantiate the Device Under Test (DUT)
    wb_stage dut (
        .clk          (clk),
        .rst_n        (rst_n),
        .wb_mem_rdata (wb_mem_rdata),
        .wb_alu_result(wb_alu_result),
        .wb_pc_plus4  (wb_pc_plus4),
        .wb_rd_addr   (wb_rd_addr),
        .wb_reg_write  (wb_reg_write),
        .wb_wb_sel    (wb_wb_sel),
        .wb_valid     (wb_valid),
        .rf_waddr     (rf_waddr),
        .rf_wdata     (rf_wdata),
        .rf_we        (rf_we),
        .wb_result    (wb_result)
    );

    // Clock generation (module has clk input, though unused)
    initial begin
        clk = 0;
        forever #5 clk = ~clk;
    end

    // Reset sequence
    initial begin
        rst_n = 0;
        #10;
        rst_n = 1;
    end

    // Task to apply stimulus
    task apply_stimulus(
        input        v,
        input [4:0]  addr,
        input        reg_write,
        input [1:0]  sel,
        input [31:0] alu,
        input [31:0] mem,
        input [31:0] pc
    );
        wb_valid       = v;
        wb_rd_addr     = addr;
        wb_reg_write   = reg_write;
        wb_wb_sel      = sel;
        wb_alu_result  = alu;
        wb_mem_rdata   = mem;
        wb_pc_plus4    = pc;
    endtask

    // Task to check outputs against expected values
    task check_outputs(
        input [4:0]  exp_rf_waddr,
        input [31:0] exp_rf_wdata,
        input        exp_rf_we,
        input [31:0] exp_wb_result,
        input string test_name
    );
        begin
            if (rf_waddr !== exp_rf_waddr) begin
                $display("FAIL [%s]: rf_waddr = %d, expected %d", test_name, rf_waddr, exp_rf_waddr);
                mismatch_count = mismatch_count + 1;
            end
            else if (rf_wdata !== exp_rf_wdata) begin
                $display("FAIL [%s]: rf_wdata = 0x%h, expected 0x%h", test_name, rf_wdata, exp_rf_wdata);
                mismatch_count = mismatch_count + 1;
            end
            else if (rf_we !== exp_rf_we) begin
                $display("FAIL [%s]: rf_we = %b, expected %b", test_name, rf_we, exp_rf_we);
                mismatch_count = mismatch_count + 1;
            end
            else if (wb_result !== exp_wb_result) begin
                $display("FAIL [%s]: wb_result = 0x%h, expected 0x%h", test_name, wb_result, exp_wb_result);
                mismatch_count = mismatch_count + 1;
            end
            else begin
                $display("PASS [%s]", test_name);
            end
        end
    endtask

    // Main test sequence
    initial begin
        // Dump waveforms
        $dumpfile("wb_stage_tb.vcd");
        $dumpvars(0, tb_wb_stage);

        // Initialize inputs
        wb_mem_rdata  = 32'd0;
        wb_alu_result = 32'd0;
        wb_pc_plus4   = 32'd0;
        wb_rd_addr    = 5'd0;
        wb_reg_write  = 1'b0;
        wb_wb_sel     = 2'b00;
        wb_valid      = 1'b0;

        // Wait for reset deassert
        #20;

        // Test 1: wb_valid = 0, all outputs should be zero
        test_num = 1;
        apply_stimulus(.v(0), .addr(5'd5), .reg_write(1), .sel(2'b00),
                       .alu(32'hA5A5A5A5), .mem(0), .pc(0));
        #1;
        check_outputs(.exp_rf_waddr(5'd0), .exp_rf_wdata(32'd0), .exp_rf_we(1'b0), .exp_wb_result(32'd0),
                      .test_name("Test 1: wb_valid=0 expecting all zero"));

        // Test 2: wb_valid=1, rd_addr=0, outputs should be zero even if reg_write=1
        test_num = 2;
        apply_stimulus(.v(1), .addr(5'd0), .reg_write(1), .sel(2'b00),
                       .alu(32'hA5A5A5A5), .mem(0), .pc(0));
        #1;
        check_outputs(.exp_rf_waddr(5'd0), .exp_rf_wdata(32'd0), .exp_rf_we(1'b0), .exp_wb_result(32'd0),
                      .test_name("Test 2: wb_valid=1, rd_addr=0 expecting all zero"));

        // Test 3: Normal operation ALU result, reg_write = 0
        test_num = 3;
        apply_stimulus(.v(1), .addr(5'd3), .reg_write(0), .sel(2'b00),
                       .alu(32'hDEADBEEF), .mem(0), .pc(0));
        #1;
        check_outputs(.exp_rf_waddr(5'd3), .exp_rf_wdata(32'hDEADBEEF), .exp_rf_we(1'b0), .exp_wb_result(32'hDEADBEEF),
                      .test_name("Test 3: sel=00 (ALU), reg_write=0, addr=3"));

        // Test 4: Memory data, reg_write = 1
        test_num = 4;
        apply_stimulus(.v(1), .addr(5'd7), .reg_write(1), .sel(2'b01),
                       .alu(0), .mem(32'h12345678), .pc(0));
        #1;
        check_outputs(.exp_rf_waddr(5'd7), .exp_rf_wdata(32'h12345678), .exp_rf_we(1'b1), .exp_wb_result(32'h12345678),
                      .test_name("Test 4: sel=01 (mem), reg_write=1, addr=7"));

        // Test 5: PC+4, reg_write = 1
        test_num = 5;
        apply_stimulus(.v(1), .addr(5'd31), .reg_write(1), .sel(2'b10),
                       .alu(0), .mem(0), .pc(32'h0000FF00));
        #1;
        check_outputs(.exp_rf_waddr(5'd31), .exp_rf_wdata(32'h0000FF00), .exp_rf_we(1'b1), .exp_wb_result(32'h0000FF00),
                      .test_name("Test 5: sel=10 (pc+4), reg_write=1, addr=31"));

        // Test 6: Default case (sel=11), reg_write=1, should output 0
        test_num = 6;
        apply_stimulus(.v(1), .addr(5'd15), .reg_write(1), .sel(2'b11),
                       .alu(32'hDEADBEEF), .mem(32'hBEEF), .pc(32'hCAFE));
        #1;
        check_outputs(.exp_rf_waddr(5'd15), .exp_rf_wdata(32'd0), .exp_rf_we(1'b1), .exp_wb_result(32'd0),
                      .test_name("Test 6: sel=11 (default), expect all selected data = 0"));

        // Test 7: Change ALU data while keeping address, immediate update
        test_num = 7;
        apply_stimulus(.v(1), .addr(5'd10), .reg_write(1), .sel(2'b00),
                       .alu(32'hABCDEF01), .mem(0), .pc(0));
        #1;
        check_outputs(.exp_rf_waddr(5'd10), .exp_rf_wdata(32'hABCDEF01), .exp_rf_we(1'b1), .exp_wb_result(32'hABCDEF01),
                      .test_name("Test 7: sel=00 (ALU), new data"));

        // Test 8: Edge: wb_valid=1, rd_addr=0, default select, still all zero
        test_num = 8;
        apply_stimulus(.v(1), .addr(5'd0), .reg_write(1), .sel(2'b11),
                       .alu(32'hFFFF), .mem(0), .pc(0));
        #1;
        check_outputs(.exp_rf_waddr(5'd0), .exp_rf_wdata(32'd0), .exp_rf_we(1'b0), .exp_wb_result(32'd0),
                      .test_name("Test 8: wb_valid=1, addr=0, sel=11 expecting all zero"));

        // Final pass/fail report
        if (mismatch_count == 0)
            $display("TEST PASSED");
        else
            $display("TEST FAILED with %0d mismatches", mismatch_count);

        $finish;
    end

endmodule