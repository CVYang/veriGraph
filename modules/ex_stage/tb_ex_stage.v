`timescale 1ns/1ps

module tb_ex_stage;

  // ---------------------------------------------------------
  // Inputs
  // ---------------------------------------------------------
  reg [31:0] ex_pc;
  reg [31:0] ex_rs1_data;
  reg [31:0] ex_rs2_data;
  reg [31:0] ex_imm;
  reg [4:0]  ex_rd_addr;
  reg        ex_alu_src;
  reg [3:0]  ex_alu_op;
  reg        ex_mem_read;
  reg        ex_mem_write;
  reg [2:0]  ex_funct3;
  reg        ex_reg_write;
  reg [1:0]  ex_wb_sel;
  reg        ex_branch;
  reg        ex_jump;
  reg        ex_jr;
  reg        ex_valid;
  reg        flush;
  reg [1:0]  fwd_alu_a;
  reg [1:0]  fwd_alu_b;
  reg [31:0] fwd_mem_result;
  reg [31:0] fwd_wb_result;
  reg [31:0] alu_result;
  reg        alu_zero;

  // ---------------------------------------------------------
  // Outputs
  // ---------------------------------------------------------
  wire [31:0] alu_a;
  wire [31:0] alu_b;
  wire [3:0]  alu_op;
  wire        branch_taken;
  wire [31:0] branch_target;
  wire [31:0] ex_alu_result;
  wire [31:0] ex_mem_wdata;
  wire [4:0]  ex_rd_addr_out;
  wire        ex_mem_read_out;
  wire        ex_mem_write_out;
  wire [2:0]  ex_funct3_out;
  wire        ex_reg_write_out;
  wire [1:0]  ex_wb_sel_out;
  wire        ex_valid_out;

  // ---------------------------------------------------------
  // Instantiate DUT
  // ---------------------------------------------------------
  ex_stage dut (
    .ex_pc             (ex_pc),
    .ex_rs1_data       (ex_rs1_data),
    .ex_rs2_data       (ex_rs2_data),
    .ex_imm            (ex_imm),
    .ex_rd_addr        (ex_rd_addr),
    .ex_alu_src        (ex_alu_src),
    .ex_alu_op         (ex_alu_op),
    .ex_mem_read       (ex_mem_read),
    .ex_mem_write      (ex_mem_write),
    .ex_funct3         (ex_funct3),
    .ex_reg_write      (ex_reg_write),
    .ex_wb_sel         (ex_wb_sel),
    .ex_branch         (ex_branch),
    .ex_jump           (ex_jump),
    .ex_jr             (ex_jr),
    .ex_valid          (ex_valid),
    .flush             (flush),
    .fwd_alu_a         (fwd_alu_a),
    .fwd_alu_b         (fwd_alu_b),
    .fwd_mem_result    (fwd_mem_result),
    .fwd_wb_result     (fwd_wb_result),
    .alu_result        (alu_result),
    .alu_zero          (alu_zero),
    .alu_a             (alu_a),
    .alu_b             (alu_b),
    .alu_op            (alu_op),
    .branch_taken      (branch_taken),
    .branch_target     (branch_target),
    .ex_alu_result     (ex_alu_result),
    .ex_mem_wdata      (ex_mem_wdata),
    .ex_rd_addr_out    (ex_rd_addr_out),
    .ex_mem_read_out   (ex_mem_read_out),
    .ex_mem_write_out  (ex_mem_write_out),
    .ex_funct3_out     (ex_funct3_out),
    .ex_reg_write_out  (ex_reg_write_out),
    .ex_wb_sel_out     (ex_wb_sel_out),
    .ex_valid_out      (ex_valid_out)
  );

  // ---------------------------------------------------------
  // Waveform dump
  // ---------------------------------------------------------
  initial begin
    $dumpfile("ex_stage_tb.vcd");
    $dumpvars(0, tb_ex_stage);
  end

  // ---------------------------------------------------------
  // Test infrastructure
  // ---------------------------------------------------------
  integer pass_cnt, fail_cnt;

  // Expected values
  reg [31:0] expected_alu_a;
  reg [31:0] expected_alu_b;
  reg [3:0]  expected_alu_op;
  reg        expected_branch_taken;
  reg [31:0] expected_branch_target;
  reg [31:0] expected_ex_alu_result;
  reg [31:0] expected_ex_mem_wdata;
  reg [4:0]  expected_ex_rd_addr_out;
  reg        expected_ex_mem_read_out;
  reg        expected_ex_mem_write_out;
  reg [2:0]  expected_ex_funct3_out;
  reg        expected_ex_reg_write_out;
  reg [1:0]  expected_ex_wb_sel_out;
  reg        expected_ex_valid_out;

  // Self-checking task
  task automatic check;
    input string msg;
    reg fail_flag;
    begin
      fail_flag = 0;

      if (alu_a !== expected_alu_a) begin
        $display("ERROR [%s]: alu_a = %h, expected %h", msg, alu_a, expected_alu_a);
        fail_flag = 1;
      end
      if (alu_b !== expected_alu_b) begin
        $display("ERROR [%s]: alu_b = %h, expected %h", msg, alu_b, expected_alu_b);
        fail_flag = 1;
      end
      if (alu_op !== expected_alu_op) begin
        $display("ERROR [%s]: alu_op = %h, expected %h", msg, alu_op, expected_alu_op);
        fail_flag = 1;
      end
      if (branch_taken !== expected_branch_taken) begin
        $display("ERROR [%s]: branch_taken = %b, expected %b", msg, branch_taken, expected_branch_taken);
        fail_flag = 1;
      end
      if (branch_target !== expected_branch_target) begin
        $display("ERROR [%s]: branch_target = %h, expected %h", msg, branch_target, expected_branch_target);
        fail_flag = 1;
      end
      if (ex_alu_result !== expected_ex_alu_result) begin
        $display("ERROR [%s]: ex_alu_result = %h, expected %h", msg, ex_alu_result, expected_ex_alu_result);
        fail_flag = 1;
      end
      if (ex_mem_wdata !== expected_ex_mem_wdata) begin
        $display("ERROR [%s]: ex_mem_wdata = %h, expected %h", msg, ex_mem_wdata, expected_ex_mem_wdata);
        fail_flag = 1;
      end
      if (ex_rd_addr_out !== expected_ex_rd_addr_out) begin
        $display("ERROR [%s]: ex_rd_addr_out = %d, expected %d", msg, ex_rd_addr_out, expected_ex_rd_addr_out);
        fail_flag = 1;
      end
      if (ex_mem_read_out !== expected_ex_mem_read_out) begin
        $display("ERROR [%s]: ex_mem_read_out = %b, expected %b", msg, ex_mem_read_out, expected_ex_mem_read_out);
        fail_flag = 1;
      end
      if (ex_mem_write_out !== expected_ex_mem_write_out) begin
        $display("ERROR [%s]: ex_mem_write_out = %b, expected %b", msg, ex_mem_write_out, expected_ex_mem_write_out);
        fail_flag = 1;
      end
      if (ex_funct3_out !== expected_ex_funct3_out) begin
        $display("ERROR [%s]: ex_funct3_out = %b, expected %b", msg, ex_funct3_out, expected_ex_funct3_out);
        fail_flag = 1;
      end
      if (ex_reg_write_out !== expected_ex_reg_write_out) begin
        $display("ERROR [%s]: ex_reg_write_out = %b, expected %b", msg, ex_reg_write_out, expected_ex_reg_write_out);
        fail_flag = 1;
      end
      if (ex_wb_sel_out !== expected_ex_wb_sel_out) begin
        $display("ERROR [%s]: ex_wb_sel_out = %b, expected %b", msg, ex_wb_sel_out, expected_ex_wb_sel_out);
        fail_flag = 1;
      end
      if (ex_valid_out !== expected_ex_valid_out) begin
        $display("ERROR [%s]: ex_valid_out = %b, expected %b", msg, ex_valid_out, expected_ex_valid_out);
        fail_flag = 1;
      end

      if (fail_flag == 0) begin
        $display("PASS [%s]", msg);
        pass_cnt = pass_cnt + 1;
      end else begin
        fail_cnt = fail_cnt + 1;
      end
    end
  endtask

  // ---------------------------------------------------------
  // Test sequence
  // ---------------------------------------------------------
  initial begin
    pass_cnt = 0;
    fail_cnt = 0;

    // ---------- Test 1: Normal operation, no forwarding ----------
    ex_pc         = 32'h1000;
    ex_rs1_data   = 32'hAAAA;
    ex_rs2_data   = 32'h5555;
    ex_imm        = 32'h100;
    ex_rd_addr    = 5'd10;
    ex_alu_src    = 0;
    ex_alu_op     = 4'b0001;
    ex_mem_read   = 1;
    ex_mem_write  = 1;
    ex_funct3     = 3'b010;
    ex_reg_write  = 1;
    ex_wb_sel     = 2'b11;
    ex_branch     = 0;
    ex_jump       = 0;
    ex_jr         = 0;
    ex_valid      = 1;
    flush         = 0;
    fwd_alu_a     = 2'b00;
    fwd_alu_b     = 2'b00;
    fwd_mem_result = 32'hDEAD;
    fwd_wb_result  = 32'hBEEF;
    alu_result    = 32'h1234_5678;
    alu_zero      = 0;

    expected_alu_a             = ex_rs1_data;
    expected_alu_b             = ex_rs2_data;
    expected_alu_op            = ex_alu_op;
    expected_branch_taken      = 0;
    expected_branch_target     = 32'h0;
    expected_ex_alu_result     = alu_result;
    expected_ex_mem_wdata      = ex_rs2_data;
    expected_ex_rd_addr_out    = ex_rd_addr;
    expected_ex_mem_read_out   = ex_mem_read;
    expected_ex_mem_write_out  = ex_mem_write;
    expected_ex_funct3_out     = ex_funct3;
    expected_ex_reg_write_out  = ex_reg_write;
    expected_ex_wb_sel_out     = ex_wb_sel;
    expected_ex_valid_out      = ex_valid;
    #10;
    check("Test01: Normal operation, no forwarding");

    // ---------- Test 2: ALU A forward from MEM ----------
    fwd_alu_a = 2'b01;  // forward from fwd_mem_result
    expected_alu_a = fwd_mem_result;
    expected_alu_b = ex_rs2_data;  // unchanged
    #10;
    check("Test02: ALU A forward from MEM");

    // ---------- Test 3: ALU A forward from WB ----------
    fwd_alu_a = 2'b10;
    expected_alu_a = fwd_wb_result;
    #10;
    check("Test03: ALU A forward from WB");

    // ---------- Test 4: ALU A default (2'b11) -> 0 ----------
    fwd_alu_a = 2'b11;
    expected_alu_a = 32'h0;
    #10;
    check("Test04: ALU A forward default -> 0");

    // ---------- Test 5: ALU B forward from MEM ----------
    fwd_alu_a = 2'b00;  // restore A
    fwd_alu_b = 2'b01;
    expected_alu_a = ex_rs1_data;
    expected_alu_b = fwd_mem_result;
    expected_ex_mem_wdata = fwd_mem_result;
    #10;
    check("Test05: ALU B forward from MEM");

    // ---------- Test 6: ALU B forward from WB ----------
    fwd_alu_b = 2'b10;
    expected_alu_b = fwd_wb_result;
    expected_ex_mem_wdata = fwd_wb_result;
    #10;
    check("Test06: ALU B forward from WB");

    // ---------- Test 7: ALU B default (2'b11) -> 0 ----------
    fwd_alu_b = 2'b11;
    expected_alu_b = 32'h0;
    expected_ex_mem_wdata = 32'h0;
    #10;
    check("Test07: ALU B forward default -> 0");

    // ---------- Test 8: ALU B immediate, ex_mem_wdata uses raw ----------
    fwd_alu_b = 2'b00;          // raw rs2 = 0x5555
    ex_alu_src = 1;
    ex_imm = 32'hF0F0;
    expected_alu_a = ex_rs1_data;
    expected_alu_b = ex_imm;    // alu_src selects imm
    expected_ex_mem_wdata = ex_rs2_data;  // raw rs2
    #10;
    check("Test08: ALU B immediate, mem_wdata stays raw");

    // ---------- Test 9: Branch BEQ taken (alu_zero=1) ----------
    ex_alu_src    = 0;
    ex_imm        = 32'h0010;
    ex_pc         = 32'h1000;
    ex_rs1_data   = 32'h200;
    ex_rs2_data   = 32'h200;
    fwd_alu_a     = 2'b00;
    fwd_alu_b     = 2'b00;
    alu_zero      = 1;
    ex_branch     = 1;
    ex_jump       = 0;
    ex_jr         = 0;
    ex_funct3     = 3'b000;  // BEQ
    ex_mem_read   = 1; ex_mem_write = 1; ex_reg_write = 1; ex_valid = 1;
    flush         = 0;

    expected_alu_a = ex_rs1_data;
    expected_alu_b = ex_rs2_data;
    expected_branch_taken = 1;
    expected_branch_target = 32'h1000 + 32'h0010;
    expected_ex_alu_result = alu_result;
    expected_ex_mem_wdata  = ex_rs2_data;
    expected_ex_rd_addr_out = ex_rd_addr;
    expected_ex_mem_read_out = 1; expected_ex_mem_write_out = 1;
    expected_ex_funct3_out = 3'b000;
    expected_ex_reg_write_out = 1;
    expected_ex_wb_sel_out = ex_wb_sel;
    expected_ex_valid_out = 1;
    #10;
    check("Test09: Branch BEQ taken (alu_zero=1)");

    // ---------- Test10: Branch BEQ not taken (alu_zero=0) ----------
    alu_zero = 0;
    expected_branch_taken = 0;
    // branch_target still becomes pc+imm because of RTL assignment
    expected_branch_target = 32'h1000 + 32'h0010;
    #10;
    check("Test10: Branch BEQ not taken, target still pc+imm");

    // ---------- Test11: BNE taken (alu_zero=0) ----------
    ex_funct3 = 3'b001;  // BNE
    alu_zero = 0;
    expected_branch_taken = 1;
    expected_branch_target = 32'h1000 + 32'h0010;
    #10;
    check("Test11: BNE taken (alu_zero=0)");

    // ---------- Test12: BNE not taken (alu_zero=1) ----------
    alu_zero = 1;
    expected_branch_taken = 0;
    #10;
    check("Test12: BNE not taken (alu_zero=1)");

    // ---------- Test13: BLT signed less than, taken ----------
    ex_funct3 = 3'b100;  // BLT
    ex_rs1_data = 32'hFFFFFFF6;  // -10
    ex_rs2_data = 32'h00000005;  //  5
    alu_zero = 0;                // not used
    expected_alu_a = ex_rs1_data;
    expected_alu_b = ex_rs2_data;
    expected_branch_taken = 1;
    expected_branch_target = 32'h1000 + 32'h0010;
    #10;
    check("Test13: BLT signed less than, taken");

    // ---------- Test14: BLT not taken ----------
    ex_rs1_data = 32'd10;
    ex_rs2_data = 32'hFFFFFFFB;  // -5
    expected_branch_taken = 0;
    #10;
    check("Test14: BLT signed not less, not taken");

    // ---------- Test15: BGE signed greater or equal, taken ----------
    ex_funct3 = 3'b101;  // BGE
    expected_branch_taken = 1;  // 10 >= -5
    #10;
    check("Test15: BGE signed greater or equal, taken");

    // ---------- Test16: BGE not taken ----------
    ex_rs1_data = 32'hFFFFFFF6;  // -10
    ex_rs2_data = 32'd5;
    expected_branch_taken = 0;   // -10 < 5
    #10;
    check("Test16: BGE signed less, not taken");

    // ---------- Test17: BLTU unsigned less, taken ----------
    ex_funct3 = 3'b110;  // BLTU
    ex_rs1_data = 32'd5;
    ex_rs2_data = 32'd10;
    expected_branch_taken = 1;
    #10;
    check("Test17: BLTU unsigned less, taken");

    // ---------- Test18: BLTU not taken ----------
    ex_rs1_data = 32'hFFFFFFFF;
    ex_rs2_data = 32'h00000001;
    expected_branch_taken = 0;
    #10;
    check("Test18: BLTU unsigned not less, not taken");

    // ---------- Test19: BGEU unsigned greater or equal, taken ----------
    ex_funct3 = 3'b111;  // BGEU
    expected_branch_taken = 1;  // 0xFFFFFFFF >= 0x00000001
    #10;
    check("Test19: BGEU unsigned greater or equal, taken");

    // ---------- Test20: BGEU not taken ----------
    ex_rs1_data = 32'd1;
    ex_rs2_data = 32'hFFFFFFFF;
    expected_branch_taken = 0;  // 1 < 0xFFFFFFFF
    #10;
    check("Test20: BGEU unsigned less, not taken");

    // ---------- Test21: JAL jump ----------
    ex_jump = 1; ex_branch = 0; ex_jr = 0;
    ex_pc = 32'h2000; ex_imm = 32'h0040;
    expected_branch_taken = 1;
    expected_branch_target = 32'h2000 + 32'h0040;
    expected_ex_valid_out = 1;  // still valid
    #10;
    check("Test21: JAL jump taken, target = pc+imm");

    // ---------- Test22: JAL overrides branch ----------
    ex_jump = 1; ex_branch = 1; ex_funct3 = 3'b000; alu_zero = 1;
    expected_branch_taken = 1;
    expected_branch_target = 32'h2000 + 32'h0040;  // still pc+imm
    #10;
    check("Test22: JAL overrides branch, target still pc+imm");

    // ---------- Test23: JALR jump ----------
    ex_jump = 0; ex_jr = 1; ex_branch = 0;
    alu_result = 32'hABCD;
    expected_branch_taken = 1;
    expected_branch_target = alu_result;
    #10;
    check("Test23: JALR jump taken, target = alu_result");

    // ---------- Test24: Flush forces control outputs to 0 ----------
    flush = 1;
    ex_jump = 0; ex_jr = 0; ex_branch = 0;
    ex_mem_read = 1; ex_mem_write = 1; ex_reg_write = 1; ex_valid = 1;
    alu_result = 32'hDEADBEEF;
    ex_rd_addr = 5'd15;
    ex_funct3 = 3'b101;
    ex_wb_sel = 2'b01;
    ex_rs2_data = 32'hCAFE; fwd_alu_b = 2'b00;  // alu_b_raw = CAFE
    ex_alu_src = 0;

    expected_alu_a = ex_rs1_data;   // not affected by flush
    expected_alu_b = ex_rs2_data;
    expected_ex_alu_result = alu_result;
    expected_ex_mem_wdata  = ex_rs2_data;
    expected_ex_rd_addr_out = ex_rd_addr;
    expected_ex_funct3_out = ex_funct3;
    expected_ex_wb_sel_out = ex_wb_sel;
    expected_ex_mem_read_out = 0;
    expected_ex_mem_write_out = 0;
    expected_ex_reg_write_out = 0;
    expected_ex_valid_out = 0;
    expected_branch_taken = 0;
    expected_branch_target = 32'h0;
    #10;
    check("Test24: Flush forces control outputs to 0, data pass through");

    // ---------- Test25: Flush ignores jump ----------
    flush = 1; ex_jump = 1;
    expected_branch_taken = 0;
    expected_branch_target = 32'h0;
    #10;
    check("Test25: Flush ignores jump, branch_taken=0");

    // ---------- Test26: ex_valid=0 but jump still takes effect ----------
    flush = 0; ex_jump = 1; ex_jr = 0; ex_branch = 0; ex_valid = 0;
    ex_pc = 32'h3000; ex_imm = 32'h0008;
    expected_ex_valid_out = 0;
    expected_branch_taken = 1;
    expected_branch_target = 32'h3000 + 32'h0008;
    #10;
    check("Test26: ex_valid=0, but jump still taken");

    // ---------- Test27: ALU B imm overrides forwarding, mem_wdata raw ----------
    ex_jump = 0; ex_valid = 1; flush = 0;
    ex_alu_src = 1; ex_imm = 32'hABCD;
    fwd_alu_b = 2'b01; fwd_mem_result = 32'h1111;
    ex_rs2_data = 32'h2222;
    expected_alu_b = ex_imm;
    expected_ex_mem_wdata = fwd_mem_result;  // alu_b_raw
    #10;
    check("Test27: ALU B imm overrides forwarding, mem_wdata raw");

    // ---------- Test28: ALU op pass-through ----------
    ex_alu_op = 4'b1010;
    expected_alu_op = ex_alu_op;
    #10;
    check("Test28: ALU op pass-through 4'b1010");

    // ---------- Final report ----------
    $display("----------------------------------------------------");
    $display("Test Summary: %0d PASSED, %0d FAILED", pass_cnt, fail_cnt);
    if (fail_cnt == 0)
      $display("*** ALL TESTS PASSED ***");
    else
      $display("*** SOME TESTS FAILED ***");
    $finish;
  end

endmodule