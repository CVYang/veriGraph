`timescale 1ns/1ps

module tb_id_ex_reg;

  // DUT inputs
  reg        clk;
  reg        rst_n;
  reg        flush;
  reg [4:0]  id_rs1_addr;
  reg [4:0]  id_rs2_addr;
  reg [31:0] id_rs1_data;
  reg [31:0] id_rs2_data;
  reg [31:0] id_imm;
  reg [4:0]  id_rd_addr;
  reg [31:0] id_pc;
  reg        id_alu_src;
  reg [3:0]  id_alu_op;
  reg        id_mem_read;
  reg        id_mem_write;
  reg [2:0]  id_funct3;
  reg        id_reg_write;
  reg [1:0]  id_wb_sel;
  reg        id_branch;
  reg        id_jump;
  reg        id_jr;
  reg        id_valid;

  // DUT outputs
  wire [4:0]  ex_rs1_addr;
  wire [4:0]  ex_rs2_addr;
  wire [31:0] ex_rs1_data;
  wire [31:0] ex_rs2_data;
  wire [31:0] ex_imm;
  wire [4:0]  ex_rd_addr;
  wire [31:0] ex_pc;
  wire        ex_alu_src;
  wire [3:0]  ex_alu_op;
  wire        ex_mem_read;
  wire        ex_mem_write;
  wire [2:0]  ex_funct3;
  wire        ex_reg_write;
  wire [1:0]  ex_wb_sel;
  wire        ex_branch;
  wire        ex_jump;
  wire        ex_jr;
  wire        ex_valid;

  // Instantiate DUT
  id_ex_reg dut (
    .clk          (clk),
    .rst_n        (rst_n),
    .flush        (flush),
    .id_rs1_addr  (id_rs1_addr),
    .id_rs2_addr  (id_rs2_addr),
    .id_rs1_data  (id_rs1_data),
    .id_rs2_data  (id_rs2_data),
    .id_imm       (id_imm),
    .id_rd_addr   (id_rd_addr),
    .id_pc        (id_pc),
    .id_alu_src   (id_alu_src),
    .id_alu_op    (id_alu_op),
    .id_mem_read  (id_mem_read),
    .id_mem_write (id_mem_write),
    .id_funct3    (id_funct3),
    .id_reg_write (id_reg_write),
    .id_wb_sel    (id_wb_sel),
    .id_branch    (id_branch),
    .id_jump      (id_jump),
    .id_jr        (id_jr),
    .id_valid     (id_valid),
    .ex_rs1_addr  (ex_rs1_addr),
    .ex_rs2_addr  (ex_rs2_addr),
    .ex_rs1_data  (ex_rs1_data),
    .ex_rs2_data  (ex_rs2_data),
    .ex_imm       (ex_imm),
    .ex_rd_addr   (ex_rd_addr),
    .ex_pc        (ex_pc),
    .ex_alu_src   (ex_alu_src),
    .ex_alu_op    (ex_alu_op),
    .ex_mem_read  (ex_mem_read),
    .ex_mem_write (ex_mem_write),
    .ex_funct3    (ex_funct3),
    .ex_reg_write (ex_reg_write),
    .ex_wb_sel    (ex_wb_sel),
    .ex_branch    (ex_branch),
    .ex_jump      (ex_jump),
    .ex_jr        (ex_jr),
    .ex_valid     (ex_valid)
  );

  // Clock generation: 10 ns period
  always #5 clk = ~clk;

  // Test control
  integer errors;
  integer test_num;

  // Previous output storage for flush test
  reg [4:0]  prev_ex_rs1_addr;
  reg [4:0]  prev_ex_rs2_addr;
  reg [31:0] prev_ex_rs1_data;
  reg [31:0] prev_ex_rs2_data;
  reg [31:0] prev_ex_imm;
  reg [4:0]  prev_ex_rd_addr;
  reg [31:0] prev_ex_pc;
  reg        prev_ex_alu_src;
  reg [3:0]  prev_ex_alu_op;
  reg        prev_ex_mem_read;
  reg        prev_ex_mem_write;
  reg [2:0]  prev_ex_funct3;
  reg        prev_ex_reg_write;
  reg [1:0]  prev_ex_wb_sel;
  reg        prev_ex_branch;
  reg        prev_ex_jump;
  reg        prev_ex_jr;
  reg        prev_ex_valid;

  // Save current output state
  task save_outputs;
    begin
      prev_ex_rs1_addr  = ex_rs1_addr;
      prev_ex_rs2_addr  = ex_rs2_addr;
      prev_ex_rs1_data  = ex_rs1_data;
      prev_ex_rs2_data  = ex_rs2_data;
      prev_ex_imm       = ex_imm;
      prev_ex_rd_addr   = ex_rd_addr;
      prev_ex_pc        = ex_pc;
      prev_ex_alu_src   = ex_alu_src;
      prev_ex_alu_op    = ex_alu_op;
      prev_ex_mem_read  = ex_mem_read;
      prev_ex_mem_write = ex_mem_write;
      prev_ex_funct3    = ex_funct3;
      prev_ex_reg_write = ex_reg_write;
      prev_ex_wb_sel    = ex_wb_sel;
      prev_ex_branch    = ex_branch;
      prev_ex_jump      = ex_jump;
      prev_ex_jr        = ex_jr;
      prev_ex_valid     = ex_valid;
    end
  endtask

  // Check all outputs against expected values
  task check_outputs;
    input [4:0]  exp_rs1_addr;
    input [4:0]  exp_rs2_addr;
    input [31:0] exp_rs1_data;
    input [31:0] exp_rs2_data;
    input [31:0] exp_imm;
    input [4:0]  exp_rd_addr;
    input [31:0] exp_pc;
    input        exp_alu_src;
    input [3:0]  exp_alu_op;
    input        exp_mem_read;
    input        exp_mem_write;
    input [2:0]  exp_funct3;
    input        exp_reg_write;
    input [1:0]  exp_wb_sel;
    input        exp_branch;
    input        exp_jump;
    input        exp_jr;
    input        exp_valid;
    begin
      if (ex_rs1_addr !== exp_rs1_addr) begin
        $display("ERROR: Test %0d - ex_rs1_addr mismatch. Expected %h, Got %h", test_num, exp_rs1_addr, ex_rs1_addr);
        errors = errors + 1;
      end
      if (ex_rs2_addr !== exp_rs2_addr) begin
        $display("ERROR: Test %0d - ex_rs2_addr mismatch. Expected %h, Got %h", test_num, exp_rs2_addr, ex_rs2_addr);
        errors = errors + 1;
      end
      if (ex_rs1_data !== exp_rs1_data) begin
        $display("ERROR: Test %0d - ex_rs1_data mismatch. Expected %h, Got %h", test_num, exp_rs1_data, ex_rs1_data);
        errors = errors + 1;
      end
      if (ex_rs2_data !== exp_rs2_data) begin
        $display("ERROR: Test %0d - ex_rs2_data mismatch. Expected %h, Got %h", test_num, exp_rs2_data, ex_rs2_data);
        errors = errors + 1;
      end
      if (ex_imm !== exp_imm) begin
        $display("ERROR: Test %0d - ex_imm mismatch. Expected %h, Got %h", test_num, exp_imm, ex_imm);
        errors = errors + 1;
      end
      if (ex_rd_addr !== exp_rd_addr) begin
        $display("ERROR: Test %0d - ex_rd_addr mismatch. Expected %h, Got %h", test_num, exp_rd_addr, ex_rd_addr);
        errors = errors + 1;
      end
      if (ex_pc !== exp_pc) begin
        $display("ERROR: Test %0d - ex_pc mismatch. Expected %h, Got %h", test_num, exp_pc, ex_pc);
        errors = errors + 1;
      end
      if (ex_alu_src !== exp_alu_src) begin
        $display("ERROR: Test %0d - ex_alu_src mismatch. Expected %b, Got %b", test_num, exp_alu_src, ex_alu_src);
        errors = errors + 1;
      end
      if (ex_alu_op !== exp_alu_op) begin
        $display("ERROR: Test %0d - ex_alu_op mismatch. Expected %h, Got %h", test_num, exp_alu_op, ex_alu_op);
        errors = errors + 1;
      end
      if (ex_mem_read !== exp_mem_read) begin
        $display("ERROR: Test %0d - ex_mem_read mismatch. Expected %b, Got %b", test_num, exp_mem_read, ex_mem_read);
        errors = errors + 1;
      end
      if (ex_mem_write !== exp_mem_write) begin
        $display("ERROR: Test %0d - ex_mem_write mismatch. Expected %b, Got %b", test_num, exp_mem_write, ex_mem_write);
        errors = errors + 1;
      end
      if (ex_funct3 !== exp_funct3) begin
        $display("ERROR: Test %0d - ex_funct3 mismatch. Expected %h, Got %h", test_num, exp_funct3, ex_funct3);
        errors = errors + 1;
      end
      if (ex_reg_write !== exp_reg_write) begin
        $display("ERROR: Test %0d - ex_reg_write mismatch. Expected %b, Got %b", test_num, exp_reg_write, ex_reg_write);
        errors = errors + 1;
      end
      if (ex_wb_sel !== exp_wb_sel) begin
        $display("ERROR: Test %0d - ex_wb_sel mismatch. Expected %h, Got %h", test_num, exp_wb_sel, ex_wb_sel);
        errors = errors + 1;
      end
      if (ex_branch !== exp_branch) begin
        $display("ERROR: Test %0d - ex_branch mismatch. Expected %b, Got %b", test_num, exp_branch, ex_branch);
        errors = errors + 1;
      end
      if (ex_jump !== exp_jump) begin
        $display("ERROR: Test %0d - ex_jump mismatch. Expected %b, Got %b", test_num, exp_jump, ex_jump);
        errors = errors + 1;
      end
      if (ex_jr !== exp_jr) begin
        $display("ERROR: Test %0d - ex_jr mismatch. Expected %b, Got %b", test_num, exp_jr, ex_jr);
        errors = errors + 1;
      end
      if (ex_valid !== exp_valid) begin
        $display("ERROR: Test %0d - ex_valid mismatch. Expected %b, Got %b", test_num, exp_valid, ex_valid);
        errors = errors + 1;
      end
    end
  endtask

  // Apply input values
  task apply_inputs;
    input [4:0]  addr1;
    input [4:0]  addr2;
    input [31:0] data1;
    input [31:0] data2;
    input [31:0] imm;
    input [4:0]  rd;
    input [31:0] pc;
    input        alu_src;
    input [3:0]  alu_op;
    input        mem_read;
    input        mem_write;
    input [2:0]  funct3;
    input        reg_write;
    input [1:0]  wb_sel;
    input        branch;
    input        jump;
    input        jr;
    input        valid;
    begin
      id_rs1_addr  = addr1;
      id_rs2_addr  = addr2;
      id_rs1_data  = data1;
      id_rs2_data  = data2;
      id_imm       = imm;
      id_rd_addr   = rd;
      id_pc        = pc;
      id_alu_src   = alu_src;
      id_alu_op    = alu_op;
      id_mem_read  = mem_read;
      id_mem_write = mem_write;
      id_funct3    = funct3;
      id_reg_write = reg_write;
      id_wb_sel    = wb_sel;
      id_branch    = branch;
      id_jump      = jump;
      id_jr        = jr;
      id_valid     = valid;
    end
  endtask

  // Test a normal clock cycle: apply inputs, wait for posedge, check outputs
  task test_cycle;
    input [4:0]  addr1;
    input [4:0]  addr2;
    input [31:0] data1;
    input [31:0] data2;
    input [31:0] imm;
    input [4:0]  rd;
    input [31:0] pc;
    input        alu_src;
    input [3:0]  alu_op;
    input        mem_read;
    input        mem_write;
    input [2:0]  funct3;
    input        reg_write;
    input [1:0]  wb_sel;
    input        branch;
    input        jump;
    input        jr;
    input        valid;
    begin
      test_num = test_num + 1;
      apply_inputs(addr1, addr2, data1, data2, imm, rd, pc, alu_src, alu_op, mem_read, mem_write, funct3, reg_write, wb_sel, branch, jump, jr, valid);
      @(posedge clk);
      #1;
      $display("Test %0d: Normal operation - applied inputs", test_num);
      check_outputs(addr1, addr2, data1, data2, imm, rd, pc, alu_src, alu_op, mem_read, mem_write, funct3, reg_write, wb_sel, branch, jump, jr, valid);
    end
  endtask

  // Test flush behavior: set flush, capture previous outputs, apply new inputs (should be ignored except valid)
  task test_flush;
    input [4:0]  addr1;   // dummy new inputs
    input [4:0]  addr2;
    input [31:0] data1;
    input [31:0] data2;
    input [31:0] imm;
    input [4:0]  rd;
    input [31:0] pc;
    input        alu_src;
    input [3:0]  alu_op;
    input        mem_read;
    input        mem_write;
    input [2:0]  funct3;
    input        reg_write;
    input [1:0]  wb_sel;
    input        branch;
    input        jump;
    input        jr;
    input        valid;
    begin
      test_num = test_num + 1;
      // Save current outputs before flush
      save_outputs();
      flush = 1;
      apply_inputs(addr1, addr2, data1, data2, imm, rd, pc, alu_src, alu_op, mem_read, mem_write, funct3, reg_write, wb_sel, branch, jump, jr, valid);
      @(posedge clk);
      #1;
      $display("Test %0d: Flush asserted - valid should be 0, others unchanged", test_num);
      // After flush, ex_valid should be 0, others keep previous values
      check_outputs(prev_ex_rs1_addr, prev_ex_rs2_addr, prev_ex_rs1_data, prev_ex_rs2_data,
                    prev_ex_imm, prev_ex_rd_addr, prev_ex_pc, prev_ex_alu_src, prev_ex_alu_op,
                    prev_ex_mem_read, prev_ex_mem_write, prev_ex_funct3, prev_ex_reg_write,
                    prev_ex_wb_sel, prev_ex_branch, prev_ex_jump, prev_ex_jr, 1'b0);
      flush = 0;
    end
  endtask

  // Main test sequence
  initial begin
    // Waveform dump
    $dumpfile("id_ex_reg_tb.vcd");
    $dumpvars(0, tb_id_ex_reg);

    // Initialization
    errors = 0;
    test_num = 0;
    clk = 0;
    rst_n = 0;
    flush = 0;
    id_rs1_addr  = 5'b0;
    id_rs2_addr  = 5'b0;
    id_rs1_data  = 32'b0;
    id_rs2_data  = 32'b0;
    id_imm       = 32'b0;
    id_rd_addr   = 5'b0;
    id_pc        = 32'b0;
    id_alu_src   = 1'b0;
    id_alu_op    = 4'b0;
    id_mem_read  = 1'b0;
    id_mem_write = 1'b0;
    id_funct3    = 3'b0;
    id_reg_write = 1'b0;
    id_wb_sel    = 2'b0;
    id_branch    = 1'b0;
    id_jump      = 1'b0;
    id_jr        = 1'b0;
    id_valid     = 1'b0;

    // Apply reset for a few ns
    #15;
    test_num = 1;
    $display("Test %0d: Checking reset state", test_num);
    // After reset all outputs should be zero
    #1;
    check_outputs(5'b0, 5'b0, 32'b0, 32'b0, 32'b0, 5'b0, 32'b0, 1'b0, 4'b0,
                  1'b0, 1'b0, 3'b0, 1'b0, 2'b0, 1'b0, 1'b0, 1'b0, 1'b0);

    // Release reset
    @(negedge clk); // wait a bit
    rst_n = 1;
    #2; // ensure async deassertion settled

    // Test 2: First normal cycle with random values
    test_cycle(5'd10, 5'd20, 32'hA5A5A5A5, 32'h5A5A5A5A, 32'h12345678, 5'd15, 32'h00001000,
               1'b1, 4'd5, 1'b0, 1'b1, 3'd4, 1'b1, 2'd2, 1'b0, 1'b0, 1'b0, 1'b1);

    // Test 3: Another normal cycle, toggle values
    test_cycle(5'd0, 5'd31, 32'hFFFFFFFF, 32'h0, 32'hFFFF0000, 5'd0, 32'hFFFFFFFF,
               1'b0, 4'hF, 1'b1, 1'b0, 3'd7, 1'b0, 2'd0, 1'b1, 1'b0, 1'b0, 1'b1);

    // Test 4: id_valid = 0 should produce ex_valid = 0 next cycle
    test_cycle(5'd1, 5'd2, 32'd100, 32'd200, 32'd300, 5'd5, 32'h80000000,
               1'b0, 4'd0, 1'b0, 1'b0, 3'd0, 1'b0, 2'd0, 1'b0, 1'b0, 1'b0, 1'b0);

    // Test 5: Flush test - after some normal state, assert flush
    // First set a known state
    test_cycle(5'd3, 5'd4, 32'hCAFECAFE, 32'hDEADBEEF, 32'hABCDABCD, 5'd7, 32'h12345678,
               1'b1, 4'ha, 1'b1, 1'b1, 3'd3, 1'b1, 2'd1, 1'b0, 1'b1, 1'b0, 1'b1);
    // Now flush with new (ignored) inputs
    test_flush(5'd8, 5'd9, 32'hBAADF00D, 32'hFEEDFACE, 32'h11112222, 5'd11, 32'hDEAD0000,
               1'b0, 4'h3, 1'b0, 1'b0, 3'd0, 1'b0, 2'd0, 1'b1, 1'b0, 1'b1, 1'b1);

    // Test 6: After flush, normal operation again
    test_cycle(5'd12, 5'd13, 32'h5555AAAA, 32'hAAAA5555, 32'h0000FFFF, 5'd14, 32'h20000000,
               1'b0, 4'hc, 1'b0, 1'b1, 3'd6, 1'b1, 2'd1, 1'b0, 1'b0, 1'b0, 1'b1);

    // Test 7: Edge case: max address values and all control signals high
    test_cycle(5'h1F, 5'h1F, 32'hFFFFFFFF, 32'hFFFFFFFF, 32'hFFFFFFFF, 5'h1F, 32'hFFFFFFFF,
               1'b1, 4'hF, 1'b1, 1'b1, 3'h7, 1'b1, 2'h3, 1'b1, 1'b1, 1'b1, 1'b1);

    // Test 8: Flush with all zeros (should clear valid only)
    test_flush(5'h0, 5'h0, 32'h0, 32'h0, 32'h0, 5'h0, 32'h0,
               1'b0, 4'h0, 1'b0, 1'b0, 3'h0, 1'b0, 2'h0, 1'b0, 1'b0, 1'b0, 1'b0);

    // Test 9: Normal operation after flush with mixed values
    test_cycle(5'd5, 5'd22, 32'h12345678, 32'h9ABCDEF0, 32'hFEDCBA98, 5'd13, 32'h00000001,
               1'b0, 4'd9, 1'b0, 1'b1, 3'd5, 1'b1, 2'd2, 1'b0, 1'b1, 1'b0, 1'b1);

    // Test 10: Reset active again (async reset) while flush is low
    $display("Test %0d: Applying async reset again", ++test_num);
    rst_n = 0;
    #10; // wait a few ns
    #1;
    check_outputs(5'b0, 5'b0, 32'b0, 32'b0, 32'b0, 5'b0, 32'b0, 1'b0, 4'b0,
                  1'b0, 1'b0, 3'b0, 1'b0, 2'b0, 1'b0, 1'b0, 1'b0, 1'b0);
    rst_n = 1;
    @(posedge clk); // realign

    // Final result
    if (errors == 0) begin
      $display("============================================");
      $display("ALL TESTS PASSED");
      $display("============================================");
    end else begin
      $display("============================================");
      $display("TEST FAILED with %0d errors", errors);
      $display("============================================");
    end
    $finish;
  end

endmodule