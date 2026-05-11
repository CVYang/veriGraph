`timescale 1ns/1ps
module tb_mem_wb_reg;

  // Testbench signals
  reg clk;
  reg rst_n;
  reg flush;
  reg [31:0] mem_rdata;
  reg [31:0] mem_alu_out;
  reg [4:0] mem_rd_addr;
  reg mem_reg_write;
  reg [1:0] mem_wb_sel;
  reg mem_valid;

  wire [31:0] wb_mem_rdata;
  wire [31:0] wb_alu_result;
  wire [4:0] wb_rd_addr;
  wire wb_reg_write;
  wire [1:0] wb_wb_sel;
  wire wb_valid;

  // Instantiate DUT
  mem_wb_reg dut (
    .clk(clk),
    .rst_n(rst_n),
    .flush(flush),
    .mem_rdata(mem_rdata),
    .mem_alu_out(mem_alu_out),
    .mem_rd_addr(mem_rd_addr),
    .mem_reg_write(mem_reg_write),
    .mem_wb_sel(mem_wb_sel),
    .mem_valid(mem_valid),
    .wb_mem_rdata(wb_mem_rdata),
    .wb_alu_result(wb_alu_result),
    .wb_rd_addr(wb_rd_addr),
    .wb_reg_write(wb_reg_write),
    .wb_wb_sel(wb_wb_sel),
    .wb_valid(wb_valid)
  );

  // Clock generation
  always #5 clk = ~clk;

  // Test control
  integer errors;

  // Check outputs against expected values
  task automatic check_outputs(
    input [31:0] exp_rdata,
    input [31:0] exp_alu,
    input [4:0] exp_rd,
    input exp_reg_write,
    input [1:0] exp_wb_sel,
    input exp_valid,
    input string test_name
  );
    begin
      if (wb_mem_rdata !== exp_rdata) begin
        $display("ERROR at time %0t: %s - wb_mem_rdata mismatch. Expected %h, got %h",
                 $time, test_name, exp_rdata, wb_mem_rdata);
        errors = errors + 1;
      end
      if (wb_alu_result !== exp_alu) begin
        $display("ERROR at time %0t: %s - wb_alu_result mismatch. Expected %h, got %h",
                 $time, test_name, exp_alu, wb_alu_result);
        errors = errors + 1;
      end
      if (wb_rd_addr !== exp_rd) begin
        $display("ERROR at time %0t: %s - wb_rd_addr mismatch. Expected %h, got %h",
                 $time, test_name, exp_rd, wb_rd_addr);
        errors = errors + 1;
      end
      if (wb_reg_write !== exp_reg_write) begin
        $display("ERROR at time %0t: %s - wb_reg_write mismatch. Expected %b, got %b",
                 $time, test_name, exp_reg_write, wb_reg_write);
        errors = errors + 1;
      end
      if (wb_wb_sel !== exp_wb_sel) begin
        $display("ERROR at time %0t: %s - wb_wb_sel mismatch. Expected %b, got %b",
                 $time, test_name, exp_wb_sel, wb_wb_sel);
        errors = errors + 1;
      end
      if (wb_valid !== exp_valid) begin
        $display("ERROR at time %0t: %s - wb_valid mismatch. Expected %b, got %b",
                 $time, test_name, exp_valid, wb_valid);
        errors = errors + 1;
      end
    end
  endtask

  // Apply inputs and check outputs after one clock cycle
  task automatic apply_and_check(
    input [31:0] in_rdata,
    input [31:0] in_alu,
    input [4:0] in_rd,
    input in_reg_write,
    input [1:0] in_wb_sel,
    input in_valid,
    input [31:0] exp_rdata,
    input [31:0] exp_alu,
    input [4:0] exp_rd,
    input exp_reg_write,
    input [1:0] exp_wb_sel,
    input exp_valid,
    input string test_name
  );
    begin
      @(negedge clk);
      mem_rdata   = in_rdata;
      mem_alu_out = in_alu;
      mem_rd_addr = in_rd;
      mem_reg_write = in_reg_write;
      mem_wb_sel  = in_wb_sel;
      mem_valid   = in_valid;
      @(posedge clk);
      #1; // small propagation delay
      check_outputs(exp_rdata, exp_alu, exp_rd, exp_reg_write, exp_wb_sel, exp_valid, test_name);
    end
  endtask

  // Apply inputs and just clock them through (no check)
  task automatic apply_inputs(
    input [31:0] in_rdata,
    input [31:0] in_alu,
    input [4:0] in_rd,
    input in_reg_write,
    input [1:0] in_wb_sel,
    input in_valid
  );
    begin
      @(negedge clk);
      mem_rdata   = in_rdata;
      mem_alu_out = in_alu;
      mem_rd_addr = in_rd;
      mem_reg_write = in_reg_write;
      mem_wb_sel  = in_wb_sel;
      mem_valid   = in_valid;
      @(posedge clk);
    end
  endtask

  // Main test sequence
  initial begin
    // Waveform dump
    $dumpfile("mem_wb_reg_tb.vcd");
    $dumpvars(0, tb_mem_wb_reg);

    errors = 0;
    clk   = 0;
    rst_n = 0;
    flush = 0;
    mem_rdata   = 32'h0;
    mem_alu_out = 32'h0;
    mem_rd_addr = 5'h0;
    mem_reg_write = 1'b0;
    mem_wb_sel  = 2'b0;
    mem_valid   = 1'b0;

    // Hold reset for several cycles
    #20;
    $display("Test: Reset check");
    check_outputs(32'h0, 32'h0, 5'h0, 1'b0, 2'b0, 1'b0, "Reset");

    // Release reset
    @(negedge clk);
    rst_n = 1;
    @(posedge clk);
    #1;
    $display("Test: Post-reset outputs zero");
    check_outputs(32'h0, 32'h0, 5'h0, 1'b0, 2'b0, 1'b0, "Post-reset");

    // Normal operation – transfer 1
    $display("Test: Normal operation - transfer 1");
    apply_and_check(
      32'hAABBCCDD, 32'h11223344, 5'h1A, 1'b1, 2'b10, 1'b1,
      32'hAABBCCDD, 32'h11223344, 5'h1A, 1'b1, 2'b10, 1'b1,
      "Transfer1"
    );

    // Normal operation – transfer 2
    $display("Test: Normal operation - transfer 2 (different values)");
    apply_and_check(
      32'hDEADBEEF, 32'hCAFEBABE, 5'h1F, 1'b0, 2'b01, 1'b0,
      32'hDEADBEEF, 32'hCAFEBABE, 5'h1F, 1'b0, 2'b01, 1'b0,
      "Transfer2"
    );

    // Test flush
    $display("Test: Flush operation");
    // First, load some data
    apply_inputs(32'h12345678, 32'h9ABCDEF0, 5'h0A, 1'b1, 2'b11, 1'b1);
    // Now assert flush
    @(negedge clk);
    flush = 1;
    @(posedge clk);
    #1;
    check_outputs(32'h0, 32'h0, 5'h0, 1'b0, 2'b0, 1'b0, "Flush");
    // Deassert flush and check normal transfer resumes
    @(negedge clk);
    flush = 0;
    mem_rdata   = 32'hFEDCBA98;
    mem_alu_out = 32'h76543210;
    mem_rd_addr = 5'h15;
    mem_reg_write = 1'b1;
    mem_wb_sel  = 2'b10;
    mem_valid   = 1'b1;
    @(posedge clk);
    #1;
    check_outputs(32'hFEDCBA98, 32'h76543210, 5'h15, 1'b1, 2'b10, 1'b1, "After flush");

    // Test reset overriding flush (asynchronous)
    $display("Test: Reset overrides flush");
    @(negedge clk);
    flush        = 1;
    mem_rdata    = 32'hAAAA5555;
    mem_alu_out  = 32'h5555AAAA;
    mem_rd_addr  = 5'h10;
    mem_reg_write = 1'b1;
    mem_wb_sel   = 2'b01;
    mem_valid    = 1'b1;
    rst_n = 0;  // assert reset
    #1;         // allow async reset to propagate
    check_outputs(32'h0, 32'h0, 5'h0, 1'b0, 2'b0, 1'b0, "Reset with flush active (async)");
    // Release reset while flush remains high
    @(negedge clk);
    rst_n = 1;
    @(posedge clk);
    #1;
    check_outputs(32'h0, 32'h0, 5'h0, 1'b0, 2'b0, 1'b0, "After reset release, flush still active");
    // Deassert flush, check that previous inputs now appear
    @(negedge clk);
    flush = 0;
    @(posedge clk);
    #1;
    check_outputs(32'hAAAA5555, 32'h5555AAAA, 5'h10, 1'b1, 2'b01, 1'b1, "After flush deassert");

    // Edge case: valid low
    $display("Test: valid low propagation");
    apply_and_check(
      32'hCCCCDDDD, 32'hEEEEFFFF, 5'h1E, 1'b1, 2'b11, 1'b0,
      32'hCCCCDDDD, 32'hEEEEFFFF, 5'h1E, 1'b1, 2'b11, 1'b0,
      "Valid low"
    );

    // Extreme values: all ones
    $display("Test: All ones");
    apply_and_check(
      32'hFFFFFFFF, 32'hFFFFFFFF, 5'h1F, 1'b1, 2'b11, 1'b1,
      32'hFFFFFFFF, 32'hFFFFFFFF, 5'h1F, 1'b1, 2'b11, 1'b1,
      "All ones"
    );

    // Extreme values: all zeros
    $display("Test: All zeros");
    apply_and_check(
      32'h00000000, 32'h00000000, 5'h00, 1'b0, 2'b00, 1'b0,
      32'h00000000, 32'h00000000, 5'h00, 1'b0, 2'b00, 1'b0,
      "All zeros"
    );

    // Back-to-back transfers
    $display("Test: Back-to-back transfers");
    apply_and_check(
      32'h11111111, 32'h22222222, 5'h01, 1'b1, 2'b01, 1'b1,
      32'h11111111, 32'h22222222, 5'h01, 1'b1, 2'b01, 1'b1,
      "Back-to-back 1"
    );
    apply_and_check(
      32'h33333333, 32'h44444444, 5'h02, 1'b0, 2'b10, 1'b0,
      32'h33333333, 32'h44444444, 5'h02, 1'b0, 2'b10, 1'b0,
      "Back-to-back 2"
    );

    // Final result
    if (errors == 0) begin
      $display("TEST PASSED");
    end else begin
      $display("TEST FAILED with %0d errors", errors);
    end

    $finish;
  end

endmodule