`timescale 1ns/1ps

module tb_ex_mem_reg;

    // Clock and control
    reg        clk;
    reg        rst_n;
    reg        flush;

    // Inputs to DUT
    reg [31:0] ex_alu_result;
    reg [31:0] ex_mem_wdata;
    reg [4:0]  ex_rd_addr;
    reg        ex_mem_read;
    reg        ex_mem_write;
    reg [2:0]  ex_funct3;
    reg        ex_reg_write;
    reg [1:0]  ex_wb_sel;
    reg        ex_valid;

    // Outputs from DUT
    wire [31:0] mem_alu_result;
    wire [31:0] mem_wdata;
    wire [4:0]  mem_rd_addr;
    wire        mem_read;
    wire        mem_write;
    wire [2:0]  mem_funct3;
    wire        mem_reg_write;
    wire [1:0]  mem_wb_sel;
    wire        mem_valid;

    integer errors;

    // Instantiate DUT
    ex_mem_reg dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .flush          (flush),
        .ex_alu_result  (ex_alu_result),
        .ex_mem_wdata   (ex_mem_wdata),
        .ex_rd_addr     (ex_rd_addr),
        .ex_mem_read    (ex_mem_read),
        .ex_mem_write   (ex_mem_write),
        .ex_funct3      (ex_funct3),
        .ex_reg_write   (ex_reg_write),
        .ex_wb_sel      (ex_wb_sel),
        .ex_valid       (ex_valid),
        .mem_alu_result (mem_alu_result),
        .mem_wdata      (mem_wdata),
        .mem_rd_addr    (mem_rd_addr),
        .mem_read       (mem_read),
        .mem_write      (mem_write),
        .mem_funct3     (mem_funct3),
        .mem_reg_write  (mem_reg_write),
        .mem_wb_sel     (mem_wb_sel),
        .mem_valid      (mem_valid)
    );

    // Clock generation: 10ns period
    initial clk = 0;
    always #5 clk = ~clk;

    // Task for self-checking a single test case
    task check_outputs;
        input [1024*8-1:0] test_name;
        input [31:0] exp_alu, exp_wdata;
        input [4:0]  exp_rd_addr;
        input        exp_read, exp_write;
        input [2:0]  exp_funct3;
        input        exp_reg_write;
        input [1:0]  exp_wb_sel;
        input        exp_valid;
        reg pass;
        begin
            pass = 1;
            if (mem_alu_result !== exp_alu) begin
                $display("ERROR [%0s]: mem_alu_result = %h, expected %h", test_name, mem_alu_result, exp_alu);
                pass = 0;
            end
            if (mem_wdata !== exp_wdata) begin
                $display("ERROR [%0s]: mem_wdata = %h, expected %h", test_name, mem_wdata, exp_wdata);
                pass = 0;
            end
            if (mem_rd_addr !== exp_rd_addr) begin
                $display("ERROR [%0s]: mem_rd_addr = %h, expected %h", test_name, mem_rd_addr, exp_rd_addr);
                pass = 0;
            end
            if (mem_read !== exp_read) begin
                $display("ERROR [%0s]: mem_read = %b, expected %b", test_name, mem_read, exp_read);
                pass = 0;
            end
            if (mem_write !== exp_write) begin
                $display("ERROR [%0s]: mem_write = %b, expected %b", test_name, mem_write, exp_write);
                pass = 0;
            end
            if (mem_funct3 !== exp_funct3) begin
                $display("ERROR [%0s]: mem_funct3 = %b, expected %b", test_name, mem_funct3, exp_funct3);
                pass = 0;
            end
            if (mem_reg_write !== exp_reg_write) begin
                $display("ERROR [%0s]: mem_reg_write = %b, expected %b", test_name, mem_reg_write, exp_reg_write);
                pass = 0;
            end
            if (mem_wb_sel !== exp_wb_sel) begin
                $display("ERROR [%0s]: mem_wb_sel = %b, expected %b", test_name, mem_wb_sel, exp_wb_sel);
                pass = 0;
            end
            if (mem_valid !== exp_valid) begin
                $display("ERROR [%0s]: mem_valid = %b, expected %b", test_name, mem_valid, exp_valid);
                pass = 0;
            end
            if (pass)
                $display("[%0s] PASS", test_name);
            else begin
                $display("[%0s] FAIL", test_name);
                errors = errors + 1;
            end
        end
    endtask

    // Main test sequence
    initial begin
        $dumpfile("ex_mem_reg_tb.vcd");
        $dumpvars(0, tb_ex_mem_reg);

        errors = 0;
        // Initialize inputs
        rst_n         = 1'b0;
        flush         = 1'b0;
        ex_alu_result = 32'h0;
        ex_mem_wdata  = 32'h0;
        ex_rd_addr    = 5'h0;
        ex_mem_read   = 1'b0;
        ex_mem_write  = 1'b0;
        ex_funct3     = 3'h0;
        ex_reg_write  = 1'b0;
        ex_wb_sel     = 2'h0;
        ex_valid      = 1'b0;

        // Wait for reset to take effect
        #12;
        check_outputs("RESET: outputs zero",
                      32'h0, 32'h0, 5'h0, 1'b0, 1'b0, 3'h0, 1'b0, 2'h0, 1'b0);

        // Change inputs while reset active -> outputs should stay 0
        ex_alu_result = 32'hDEAD_BEEF;
        ex_mem_wdata  = 32'hC0DE_C0DE;
        ex_rd_addr    = 5'h1F;
        ex_mem_read   = 1'b1;
        ex_mem_write  = 1'b1;
        ex_funct3     = 3'b111;
        ex_reg_write  = 1'b1;
        ex_wb_sel     = 2'b11;
        ex_valid      = 1'b1;
        #10;
        check_outputs("RESET ACTIVE: outputs remain zero",
                      32'h0, 32'h0, 5'h0, 1'b0, 1'b0, 3'h0, 1'b0, 2'h0, 1'b0);

        // Release reset
        rst_n = 1'b1;
        // Still inputs from above, but rst_n=1, next posedge will latch them
        #10;
        check_outputs("FIRST LATCH after reset release",
                      32'hDEAD_BEEF, 32'hC0DE_C0DE, 5'h1F, 1'b1, 1'b1, 3'b111, 1'b1, 2'b11, 1'b1);

        // Normal operation: load another pattern
        ex_alu_result = 32'hAAAA_5555;
        ex_mem_wdata  = 32'h5555_AAAA;
        ex_rd_addr    = 5'h0A;
        ex_mem_read   = 1'b0;
        ex_mem_write  = 1'b1;
        ex_funct3     = 3'b001;
        ex_reg_write  = 1'b0;
        ex_wb_sel     = 2'b01;
        ex_valid      = 1'b1;
        #10;
        check_outputs("NORMAL OP 1: second pattern",
                      32'hAAAA_5555, 32'h5555_AAAA, 5'h0A, 1'b0, 1'b1, 3'b001, 1'b0, 2'b01, 1'b1);

        // Test flush while normal data is present
        flush = 1'b1;
        // Inputs should be ignored during flush
        ex_alu_result = 32'h1234_5678; // ignored
        #10;
        check_outputs("FLUSH: all outputs reset to zero",
                      32'h0, 32'h0, 5'h0, 1'b0, 1'b0, 3'h0, 1'b0, 2'h0, 1'b0);

        // Release flush and apply new data
        flush = 1'b0;
        ex_alu_result = 32'hFEED_FACE;
        ex_mem_wdata  = 32'hCAFE_BABE;
        ex_rd_addr    = 5'h12;
        ex_mem_read   = 1'b1;
        ex_mem_write  = 1'b0;
        ex_funct3     = 3'b110;
        ex_reg_write  = 1'b1;
        ex_wb_sel     = 2'b10;
        ex_valid      = 1'b0;   // valid = 0, but other signals still latch
        #10;
        check_outputs("AFTER FLUSH: new data latched, valid low",
                      32'hFEED_FACE, 32'hCAFE_BABE, 5'h12, 1'b1, 1'b0, 3'b110, 1'b1, 2'b10, 1'b0);

        // Test all ones
        ex_alu_result = 32'hFFFF_FFFF;
        ex_mem_wdata  = 32'hFFFF_FFFF;
        ex_rd_addr    = 5'h1F;
        ex_mem_read   = 1'b1;
        ex_mem_write  = 1'b1;
        ex_funct3     = 3'h7;
        ex_reg_write  = 1'b1;
        ex_wb_sel     = 2'h3;
        ex_valid      = 1'b1;
        #10;
        check_outputs("ALL ONES",
                      32'hFFFF_FFFF, 32'hFFFF_FFFF, 5'h1F, 1'b1, 1'b1, 3'h7, 1'b1, 2'h3, 1'b1);

        // Test reset during active operation
        rst_n = 1'b0;
        #10;
        check_outputs("RESET (during operation): outputs zero",
                      32'h0, 32'h0, 5'h0, 1'b0, 1'b0, 3'h0, 1'b0, 2'h0, 1'b0);

        // Test simultaneous reset and flush (reset has priority)
        rst_n = 1'b0;
        flush = 1'b1;
        ex_alu_result = 32'hAAA_555; // should not appear
        #10;
        check_outputs("RESET & FLUSH together: outputs zero",
                      32'h0, 32'h0, 5'h0, 1'b0, 1'b0, 3'h0, 1'b0, 2'h0, 1'b0);

        // Release reset but keep flush high
        rst_n = 1'b1;
        // flush still 1, so outputs stay zero
        #10;
        check_outputs("FLUSH still active after reset release: outputs zero",
                      32'h0, 32'h0, 5'h0, 1'b0, 1'b0, 3'h0, 1'b0, 2'h0, 1'b0);

        // Release flush completely
        flush = 1'b0;
        ex_alu_result = 32'h9999_8888;
        ex_mem_wdata  = 32'h7777_6666;
        ex_rd_addr    = 5'h05;
        ex_mem_read   = 1'b0;
        ex_mem_write  = 1'b0;
        ex_funct3     = 3'h0;
        ex_reg_write  = 1'b0;
        ex_wb_sel     = 2'h0;
        ex_valid      = 1'b1;
        #10;
        check_outputs("NORMAL after flush release",
                      32'h9999_8888, 32'h7777_6666, 5'h05, 1'b0, 1'b0, 3'h0, 1'b0, 2'h0, 1'b1);

        // Final report
        if (errors == 0)
            $display("\n*** TEST PASSED ***");
        else
            $display("\n*** TEST FAILED with %0d error(s) ***", errors);

        #20;
        $finish;
    end

endmodule