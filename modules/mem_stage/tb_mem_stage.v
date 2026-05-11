`timescale 1ns/1ps

module tb_mem_stage;

    // DUT signals
    reg clk;
    reg rst_n;
    reg [31:0] mem_alu_result;
    reg [31:0] mem_wdata;
    reg [4:0] mem_rd_addr;
    reg mem_read;
    reg mem_write;
    reg [2:0] mem_funct3;
    reg mem_reg_write;
    reg [1:0] mem_wb_sel;
    reg mem_valid;
    reg [31:0] dmem_rdata;

    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    wire dmem_req;
    wire dmem_we;
    wire [3:0] dmem_be;
    wire [31:0] mem_rdata;
    wire [31:0] mem_alu_out;
    wire [4:0] mem_rd_addr_out;
    wire mem_reg_write_out;
    wire [1:0] mem_wb_sel_out;
    wire mem_valid_out;

    // Instantiate DUT
    mem_stage dut (
        .clk(clk),
        .rst_n(rst_n),
        .mem_alu_result(mem_alu_result),
        .mem_wdata(mem_wdata),
        .mem_rd_addr(mem_rd_addr),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .mem_funct3(mem_funct3),
        .mem_reg_write(mem_reg_write),
        .mem_wb_sel(mem_wb_sel),
        .mem_valid(mem_valid),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_req(dmem_req),
        .dmem_we(dmem_we),
        .dmem_be(dmem_be),
        .mem_rdata(mem_rdata),
        .mem_alu_out(mem_alu_out),
        .mem_rd_addr_out(mem_rd_addr_out),
        .mem_reg_write_out(mem_reg_write_out),
        .mem_wb_sel_out(mem_wb_sel_out),
        .mem_valid_out(mem_valid_out)
    );

    // Clock generation
    always #5 clk = ~clk; // 100 MHz clock

    // Waveform dump
    initial begin
        $dumpfile("mem_stage_tb.vcd");
        $dumpvars(0, tb_mem_stage);
    end

    // Test variables
    integer error_count = 0;
    integer case_num = 0;

    // Helper task to check a value
    task check_value;
        input [1023:0] desc; // large string length
        input [31:0] actual;
        input [31:0] expected;
        begin
            if (actual !== expected) begin
                $display("ERROR [Case %0d]: %s - Expected %h, got %h", case_num, desc, expected, actual);
                error_count = error_count + 1;
            end else begin
                $display("PASS  [Case %0d]: %s", case_num, desc);
            end
        end
    endtask

    // Overloaded for smaller widths
    task check_value_wide;
        input [1023:0] desc;
        input [31:0] actual;
        input [31:0] expected;
        begin
            check_value(desc, actual, expected);
        end
    endtask

    task check_value_5bit;
        input [1023:0] desc;
        input [4:0] actual;
        input [4:0] expected;
        begin
            if (actual !== expected) begin
                $display("ERROR [Case %0d]: %s - Expected %b, got %b", case_num, desc, expected, actual);
                error_count = error_count + 1;
            end else begin
                $display("PASS  [Case %0d]: %s", case_num, desc);
            end
        end
    endtask

    task check_value_2bit;
        input [1023:0] desc;
        input [1:0] actual;
        input [1:0] expected;
        begin
            if (actual !== expected) begin
                $display("ERROR [Case %0d]: %s - Expected %b, got %b", case_num, desc, expected, actual);
                error_count = error_count + 1;
            end else begin
                $display("PASS  [Case %0d]: %s", case_num, desc);
            end
        end
    endtask

    task check_value_1bit;
        input [1023:0] desc;
        input actual;
        input expected;
        begin
            if (actual !== expected) begin
                $display("ERROR [Case %0d]: %s - Expected %b, got %b", case_num, desc, expected, actual);
                error_count = error_count + 1;
            end else begin
                $display("PASS  [Case %0d]: %s", case_num, desc);
            end
        end
    endtask

    // Apply a complete test case: set inputs, wait #1, check combinational, then clock edge, check registered
    task run_test;
        input [31:0] alu_result;
        input [31:0] wdata;
        input [4:0] rd_addr;
        input read;
        input write;
        input [2:0] funct3;
        input reg_write;
        input [1:0] wb_sel;
        input valid;
        input [31:0] ext_rdata;

        // expected combinational outputs (besides dmem_be/mem_rdata which depend on many factors)
        input [31:0] exp_dmem_addr;
        input [31:0] exp_dmem_wdata;
        input exp_dmem_req;
        input exp_dmem_we;
        input [3:0] exp_dmem_be;
        input [31:0] exp_mem_rdata;

        // expected registered outputs after clock
        input [31:0] exp_alu_out;
        input [4:0] exp_rd_addr_out;
        input exp_reg_write_out;
        input [1:0] exp_wb_sel_out;
        input exp_valid_out;
        begin
            // Set inputs
            mem_alu_result = alu_result;
            mem_wdata = wdata;
            mem_rd_addr = rd_addr;
            mem_read = read;
            mem_write = write;
            mem_funct3 = funct3;
            mem_reg_write = reg_write;
            mem_wb_sel = wb_sel;
            mem_valid = valid;
            dmem_rdata = ext_rdata;

            #1; // small delay for combinational outputs to stabilize

            // Check combinational outputs
            check_value_wide("dmem_addr", dmem_addr, exp_dmem_addr);
            check_value_wide("dmem_wdata", dmem_wdata, exp_dmem_wdata);
            check_value_1bit("dmem_req", dmem_req, exp_dmem_req);
            check_value_1bit("dmem_we", dmem_we, exp_dmem_we);
            check_value("dmem_be", {28'b0, dmem_be}, {28'b0, exp_dmem_be}); // compare 4 bits
            if (read) begin
                check_value_wide("mem_rdata (combinational)", mem_rdata, exp_mem_rdata);
            end else begin
                // when not reading, mem_rdata may be 0 or undefined, but we can just skip or check it's 0
                // The module outputs 0 for default cases; we'll pass expected 0.
                check_value_wide("mem_rdata (no read)", mem_rdata, exp_mem_rdata);
            end

            // Wait for clock edge to capture registers
            @(posedge clk);

            // After posedge, check registered outputs
            check_value_wide("mem_alu_out", mem_alu_out, exp_alu_out);
            check_value_5bit("mem_rd_addr_out", mem_rd_addr_out, exp_rd_addr_out);
            check_value_1bit("mem_reg_write_out", mem_reg_write_out, exp_reg_write_out);
            check_value_2bit("mem_wb_sel_out", mem_wb_sel_out, exp_wb_sel_out);
            check_value_1bit("mem_valid_out", mem_valid_out, exp_valid_out);

            case_num = case_num + 1;
            #1; // small delay before next test
        end
    endtask

    initial begin
        // Initialize signals
        clk = 0;
        rst_n = 1;
        mem_alu_result = 32'h0;
        mem_wdata = 32'h0;
        mem_rd_addr = 5'h0;
        mem_read = 0;
        mem_write = 0;
        mem_funct3 = 3'b010;
        mem_reg_write = 0;
        mem_wb_sel = 2'b0;
        mem_valid = 0;
        dmem_rdata = 32'h0;

        // Apply reset
        rst_n = 1;
        #2;
        rst_n = 0;
        repeat (3) @(posedge clk);
        rst_n = 1;
        @(posedge clk); // release reset

        $display("Starting test cases...");

        // Test 1: After reset, registered outputs should be zero
        $display("--- Reset check ---");
        check_value_wide("mem_alu_out reset", mem_alu_out, 32'h0);
        check_value_5bit("mem_rd_addr_out reset", mem_rd_addr_out, 5'h0);
        check_value_1bit("mem_reg_write_out reset", mem_reg_write_out, 1'b0);
        check_value_2bit("mem_wb_sel_out reset", mem_wb_sel_out, 2'b0);
        check_value_1bit("mem_valid_out reset", mem_valid_out, 1'b0);
        case_num = 1;

        // Test 2: No memory operation (both read/write = 0)
        $display("--- No Memory Operation ---");
        run_test(
            .alu_result(32'hA000_0000), .wdata(32'h0), .rd_addr(5'h0A),
            .read(1'b0), .write(1'b0), .funct3(3'b010),
            .reg_write(1'b1), .wb_sel(2'b01), .valid(1'b1),
            .ext_rdata(32'hDEADBEEF), // irrelevant
            .exp_dmem_addr(32'hA000_0000), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b0), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b0000), .exp_mem_rdata(32'h0),
            .exp_alu_out(32'hA000_0000), .exp_rd_addr_out(5'h0A), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b01), .exp_valid_out(1'b1)
        );

        // Test 3: LW (funct3=010, read=1)
        // Address irrelevant to dmem_be, always 4'b1111
        // dmem_rdata = 0x12345678
        run_test(
            .alu_result(32'h1000_0000), .wdata(32'h0), .rd_addr(5'h01),
            .read(1'b1), .write(1'b0), .funct3(3'b010),
            .reg_write(1'b1), .wb_sel(2'b10), .valid(1'b1),
            .ext_rdata(32'h12345678),
            .exp_dmem_addr(32'h1000_0000), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b1111), .exp_mem_rdata(32'h12345678),
            .exp_alu_out(32'h1000_0000), .exp_rd_addr_out(5'h01), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b10), .exp_valid_out(1'b1)
        );

        // Test 4: SW (funct3=010, write=1)
        // wdata = 0xAABBCCDD
        run_test(
            .alu_result(32'h2000_0000), .wdata(32'hAABBCCDD), .rd_addr(5'h02),
            .read(1'b0), .write(1'b1), .funct3(3'b010),
            .reg_write(1'b0), .wb_sel(2'b00), .valid(1'b0),
            .ext_rdata(32'h0),
            .exp_dmem_addr(32'h2000_0000), .exp_dmem_wdata(32'hAABBCCDD), .exp_dmem_req(1'b1), .exp_dmem_we(1'b1),
            .exp_dmem_be(4'b1111), .exp_mem_rdata(32'h0),
            .exp_alu_out(32'h2000_0000), .exp_rd_addr_out(5'h02), .exp_reg_write_out(1'b0),
            .exp_wb_sel_out(2'b00), .exp_valid_out(1'b0)
        );

        // Test 5: LB (funct3=000, read=1) various offsets
        // dmem_rdata = 32'h80FF_FF80 (little-endian: byte0=0x80 neg, byte1=0xFF neg, byte2=0xFF neg, byte3=0x80 neg)
        $display("--- LB Tests ---");
        run_test(
            .alu_result(32'h3000_0000), .wdata(32'h0), .rd_addr(5'h03),
            .read(1'b1), .write(1'b0), .funct3(3'b000),
            .reg_write(1'b1), .wb_sel(2'b11), .valid(1'b1),
            .ext_rdata(32'h80FF_FF80),
            .exp_dmem_addr(32'h3000_0000), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b0001), .exp_mem_rdata({{24{1'b1}}, 8'h80}), // sign extend 0x80 -> 0xFFFFFF80
            .exp_alu_out(32'h3000_0000), .exp_rd_addr_out(5'h03), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b11), .exp_valid_out(1'b1)
        );
        run_test(
            .alu_result(32'h3000_0001), .wdata(32'h0), .rd_addr(5'h04),
            .read(1'b1), .write(1'b0), .funct3(3'b000),
            .reg_write(1'b1), .wb_sel(2'b01), .valid(1'b1),
            .ext_rdata(32'h80FF_FF80),
            .exp_dmem_addr(32'h3000_0001), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b0010), .exp_mem_rdata({ {24{dmem_rdata[15]}} , dmem_rdata[15:8]}), // 0xFF -> 0xFFFFFFFF
            .exp_alu_out(32'h3000_0001), .exp_rd_addr_out(5'h04), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b01), .exp_valid_out(1'b1)
        );
        // Quick calculation for expected: dmem_rdata[15:8] = 8'hFF, sign extended = 32'hFFFFFFFF
        // We'll set expected to 32'hFFFFFFFF
        run_test(
            .alu_result(32'h3000_0002), .wdata(32'h0), .rd_addr(5'h05),
            .read(1'b1), .write(1'b0), .funct3(3'b000),
            .reg_write(1'b1), .wb_sel(2'b10), .valid(1'b1),
            .ext_rdata(32'h80FF_FF80),
            .exp_dmem_addr(32'h3000_0002), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b0100), .exp_mem_rdata(32'hFFFFFFFF), // sign ext 0xFF
            .exp_alu_out(32'h3000_0002), .exp_rd_addr_out(5'h05), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b10), .exp_valid_out(1'b1)
        );
        run_test(
            .alu_result(32'h3000_0003), .wdata(32'h0), .rd_addr(5'h06),
            .read(1'b1), .write(1'b0), .funct3(3'b000),
            .reg_write(1'b1), .wb_sel(2'b00), .valid(1'b0),
            .ext_rdata(32'h80FF_FF80),
            .exp_dmem_addr(32'h3000_0003), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b1000), .exp_mem_rdata(32'hFFFFFF80), // sign ext 0x80
            .exp_alu_out(32'h3000_0003), .exp_rd_addr_out(5'h06), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b00), .exp_valid_out(1'b0)
        );

        // Test 6: LH (funct3=001, read=1) offsets 0 and 1
        // dmem_rdata = 32'h8000_7FFF (byte0=0xFF, byte1=0x7F, byte2=0x00, byte3=0x80)
        $display("--- LH Tests ---");
        run_test(
            .alu_result(32'h4000_0000), .wdata(32'h0), .rd_addr(5'h07),
            .read(1'b1), .write(1'b0), .funct3(3'b001),
            .reg_write(1'b1), .wb_sel(2'b11), .valid(1'b1),
            .ext_rdata(32'h8000_7FFF),
            .exp_dmem_addr(32'h4000_0000), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b0011), .exp_mem_rdata(32'h00007FFF), // sign-ext positive
            .exp_alu_out(32'h4000_0000), .exp_rd_addr_out(5'h07), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b11), .exp_valid_out(1'b1)
        );
        run_test(
            .alu_result(32'h4000_0002), .wdata(32'h0), .rd_addr(5'h08),
            .read(1'b1), .write(1'b0), .funct3(3'b001),
            .reg_write(1'b1), .wb_sel(2'b01), .valid(1'b0),
            .ext_rdata(32'h8000_7FFF),
            .exp_dmem_addr(32'h4000_0002), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b1100), .exp_mem_rdata(32'hFFFF8000), // sign-ext negative
            .exp_alu_out(32'h4000_0002), .exp_rd_addr_out(5'h08), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b01), .exp_valid_out(1'b0)
        );

        // Test 7: LBU (funct3=100, read=1) offsets
        // dmem_rdata = 32'h80FF_FF80 (same as LB) but zero-extension
        $display("--- LBU Tests ---");
        run_test(
            .alu_result(32'h5000_0000), .wdata(32'h0), .rd_addr(5'h09),
            .read(1'b1), .write(1'b0), .funct3(3'b100),
            .reg_write(1'b1), .wb_sel(2'b10), .valid(1'b1),
            .ext_rdata(32'h80FF_FF80),
            .exp_dmem_addr(32'h5000_0000), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b0001), .exp_mem_rdata({24'b0, 8'h80}), // zero-extend 0x80 -> 0x00000080
            .exp_alu_out(32'h5000_0000), .exp_rd_addr_out(5'h09), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b10), .exp_valid_out(1'b1)
        );
        run_test(
            .alu_result(32'h5000_0001), .wdata(32'h0), .rd_addr(5'h0A),
            .read(1'b1), .write(1'b0), .funct3(3'b100),
            .reg_write(1'b1), .wb_sel(2'b11), .valid(1'b1),
            .ext_rdata(32'h80FF_FF80),
            .exp_dmem_addr(32'h5000_0001), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b0010), .exp_mem_rdata({24'b0, 8'hFF}), // 0x000000FF
            .exp_alu_out(32'h5000_0001), .exp_rd_addr_out(5'h0A), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b11), .exp_valid_out(1'b1)
        );
        run_test(
            .alu_result(32'h5000_0002), .wdata(32'h0), .rd_addr(5'h0B),
            .read(1'b1), .write(1'b0), .funct3(3'b100),
            .reg_write(1'b1), .wb_sel(2'b00), .valid(1'b0),
            .ext_rdata(32'h80FF_FF80),
            .exp_dmem_addr(32'h5000_0002), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b0100), .exp_mem_rdata({24'b0, 8'hFF}), // 0x000000FF
            .exp_alu_out(32'h5000_0002), .exp_rd_addr_out(5'h0B), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b00), .exp_valid_out(1'b0)
        );
        run_test(
            .alu_result(32'h5000_0003), .wdata(32'h0), .rd_addr(5'h0C),
            .read(1'b1), .write(1'b0), .funct3(3'b100),
            .reg_write(1'b1), .wb_sel(2'b01), .valid(1'b1),
            .ext_rdata(32'h80FF_FF80),
            .exp_dmem_addr(32'h5000_0003), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b1000), .exp_mem_rdata({24'b0, 8'h80}), // 0x00000080
            .exp_alu_out(32'h5000_0003), .exp_rd_addr_out(5'h0C), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b01), .exp_valid_out(1'b1)
        );

        // Test 8: LHU (funct3=101, read=1) offsets
        // dmem_rdata = 32'h8000_7FFF
        $display("--- LHU Tests ---");
        run_test(
            .alu_result(32'h6000_0000), .wdata(32'h0), .rd_addr(5'h0D),
            .read(1'b1), .write(1'b0), .funct3(3'b101),
            .reg_write(1'b0), .wb_sel(2'b10), .valid(1'b1),
            .ext_rdata(32'h8000_7FFF),
            .exp_dmem_addr(32'h6000_0000), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b0011), .exp_mem_rdata({16'b0, 16'h7FFF}), // 0x00007FFF
            .exp_alu_out(32'h6000_0000), .exp_rd_addr_out(5'h0D), .exp_reg_write_out(1'b0),
            .exp_wb_sel_out(2'b10), .exp_valid_out(1'b1)
        );
        run_test(
            .alu_result(32'h6000_0002), .wdata(32'h0), .rd_addr(5'h0E),
            .read(1'b1), .write(1'b0), .funct3(3'b101),
            .reg_write(1'b0), .wb_sel(2'b00), .valid(1'b0),
            .ext_rdata(32'h8000_7FFF),
            .exp_dmem_addr(32'h6000_0002), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b1100), .exp_mem_rdata({16'b0, 16'h8000}), // 0x00008000
            .exp_alu_out(32'h6000_0002), .exp_rd_addr_out(5'h0E), .exp_reg_write_out(1'b0),
            .exp_wb_sel_out(2'b00), .exp_valid_out(1'b0)
        );

        // Test 9: SB (funct3=000, write=1) offsets
        $display("--- SB Tests ---");
        run_test(
            .alu_result(32'h7000_0000), .wdata(32'hCAFEBABE), .rd_addr(5'h0F),
            .read(1'b0), .write(1'b1), .funct3(3'b000),
            .reg_write(1'b0), .wb_sel(2'b01), .valid(1'b1),
            .ext_rdata(32'h0),
            .exp_dmem_addr(32'h7000_0000), .exp_dmem_wdata(32'hCAFEBABE), .exp_dmem_req(1'b1), .exp_dmem_we(1'b1),
            .exp_dmem_be(4'b0001), .exp_mem_rdata(32'h0),
            .exp_alu_out(32'h7000_0000), .exp_rd_addr_out(5'h0F), .exp_reg_write_out(1'b0),
            .exp_wb_sel_out(2'b01), .exp_valid_out(1'b1)
        );
        run_test(
            .alu_result(32'h7000_0001), .wdata(32'hCAFEBABE), .rd_addr(5'h10),
            .read(1'b0), .write(1'b1), .funct3(3'b000),
            .reg_write(1'b0), .wb_sel(2'b00), .valid(1'b0),
            .ext_rdata(32'h0),
            .exp_dmem_addr(32'h7000_0001), .exp_dmem_wdata(32'hCAFEBABE), .exp_dmem_req(1'b1), .exp_dmem_we(1'b1),
            .exp_dmem_be(4'b0010), .exp_mem_rdata(32'h0),
            .exp_alu_out(32'h7000_0001), .exp_rd_addr_out(5'h10), .exp_reg_write_out(1'b0),
            .exp_wb_sel_out(2'b00), .exp_valid_out(1'b0)
        );
        run_test(
            .alu_result(32'h7000_0002), .wdata(32'hCAFEBABE), .rd_addr(5'h11),
            .read(1'b0), .write(1'b1), .funct3(3'b000),
            .reg_write(1'b1), .wb_sel(2'b10), .valid(1'b1),
            .ext_rdata(32'h0),
            .exp_dmem_addr(32'h7000_0002), .exp_dmem_wdata(32'hCAFEBABE), .exp_dmem_req(1'b1), .exp_dmem_we(1'b1),
            .exp_dmem_be(4'b0100), .exp_mem_rdata(32'h0),
            .exp_alu_out(32'h7000_0002), .exp_rd_addr_out(5'h11), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b10), .exp_valid_out(1'b1)
        );
        run_test(
            .alu_result(32'h7000_0003), .wdata(32'hCAFEBABE), .rd_addr(5'h12),
            .read(1'b0), .write(1'b1), .funct3(3'b000),
            .reg_write(1'b1), .wb_sel(2'b11), .valid(1'b0),
            .ext_rdata(32'h0),
            .exp_dmem_addr(32'h7000_0003), .exp_dmem_wdata(32'hCAFEBABE), .exp_dmem_req(1'b1), .exp_dmem_we(1'b1),
            .exp_dmem_be(4'b1000), .exp_mem_rdata(32'h0),
            .exp_alu_out(32'h7000_0003), .exp_rd_addr_out(5'h12), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b11), .exp_valid_out(1'b0)
        );

        // Test 10: SH (funct3=001, write=1) offsets
        $display("--- SH Tests ---");
        run_test(
            .alu_result(32'h8000_0000), .wdata(32'hDEADDEAD), .rd_addr(5'h13),
            .read(1'b0), .write(1'b1), .funct3(3'b001),
            .reg_write(1'b0), .wb_sel(2'b01), .valid(1'b1),
            .ext_rdata(32'h0),
            .exp_dmem_addr(32'h8000_0000), .exp_dmem_wdata(32'hDEADDEAD), .exp_dmem_req(1'b1), .exp_dmem_we(1'b1),
            .exp_dmem_be(4'b0011), .exp_mem_rdata(32'h0),
            .exp_alu_out(32'h8000_0000), .exp_rd_addr_out(5'h13), .exp_reg_write_out(1'b0),
            .exp_wb_sel_out(2'b01), .exp_valid_out(1'b1)
        );
        run_test(
            .alu_result(32'h8000_0002), .wdata(32'hDEADDEAD), .rd_addr(5'h14),
            .read(1'b0), .write(1'b1), .funct3(3'b001),
            .reg_write(1'b1), .wb_sel(2'b10), .valid(1'b0),
            .ext_rdata(32'h0),
            .exp_dmem_addr(32'h8000_0002), .exp_dmem_wdata(32'hDEADDEAD), .exp_dmem_req(1'b1), .exp_dmem_we(1'b1),
            .exp_dmem_be(4'b1100), .exp_mem_rdata(32'h0),
            .exp_alu_out(32'h8000_0002), .exp_rd_addr_out(5'h14), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b10), .exp_valid_out(1'b0)
        );

        // Test 11: Invalid funct3 codes (3'b011, 3'b110, 3'b111)
        $display("--- Invalid funct3 tests ---");
        run_test(
            .alu_result(32'h9000_0000), .wdata(32'h0), .rd_addr(5'h15),
            .read(1'b1), .write(1'b0), .funct3(3'b011),
            .reg_write(1'b0), .wb_sel(2'b00), .valid(1'b0),
            .ext_rdata(32'hDEADBEEF),
            .exp_dmem_addr(32'h9000_0000), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b1), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b0000), .exp_mem_rdata(32'h0),
            .exp_alu_out(32'h9000_0000), .exp_rd_addr_out(5'h15), .exp_reg_write_out(1'b0),
            .exp_wb_sel_out(2'b00), .exp_valid_out(1'b0)
        );
        run_test(
            .alu_result(32'h9000_0004), .wdata(32'h12345678), .rd_addr(5'h16),
            .read(1'b0), .write(1'b1), .funct3(3'b110),
            .reg_write(1'b1), .wb_sel(2'b11), .valid(1'b1),
            .ext_rdata(32'h0),
            .exp_dmem_addr(32'h9000_0004), .exp_dmem_wdata(32'h12345678), .exp_dmem_req(1'b1), .exp_dmem_we(1'b1),
            .exp_dmem_be(4'b0000), .exp_mem_rdata(32'h0),
            .exp_alu_out(32'h9000_0004), .exp_rd_addr_out(5'h16), .exp_reg_write_out(1'b1),
            .exp_wb_sel_out(2'b11), .exp_valid_out(1'b1)
        );
        run_test(
            .alu_result(32'h9000_0008), .wdata(32'h0), .rd_addr(5'h17),
            .read(1'b0), .write(1'b0), .funct3(3'b111),
            .reg_write(1'b0), .wb_sel(2'b01), .valid(1'b1),
            .ext_rdata(32'h0),
            .exp_dmem_addr(32'h9000_0008), .exp_dmem_wdata(32'h0), .exp_dmem_req(1'b0), .exp_dmem_we(1'b0),
            .exp_dmem_be(4'b0000), .exp_mem_rdata(32'h0),
            .exp_alu_out(32'h9000_0008), .exp_rd_addr_out(5'h17), .exp_reg_write_out(1'b0),
            .exp_wb_sel_out(2'b01), .exp_valid_out(1'b1)
        );

        // Test 12: Corner case: funct3 with read=1 but no write, and address bits causing all BE patterns
        // Already covered

        // Test summary
        if (error_count == 0) begin
            $display("\n====================================");
            $display("           TEST PASSED");
            $display("====================================\n");
        end else begin
            $display("\n====================================");
            $display("           TEST FAILED ");
            $display("====================================");
            $display("Total errors: %0d", error_count);
            $display("====================================\n");
        end

        #10 $finish;
    end

endmodule