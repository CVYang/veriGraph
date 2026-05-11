`timescale 1ns/1ps

module tb_hazard_unit;

    // Clock and reset
    reg clk;
    reg rst_n;

    // ID Stage inputs
    reg [4:0]  id_rs1_addr;
    reg [4:0]  id_rs2_addr;
    reg        id_branch;
    reg        id_jump;
    reg        id_jr;

    // EX Stage inputs
    reg [4:0]  ex_rd_addr;
    reg        ex_mem_read;
    reg        ex_reg_write;
    reg [31:0] ex_result;

    // MEM Stage inputs
    reg [4:0]  mem_rd_addr;
    reg        mem_reg_write;
    reg [31:0] mem_result;

    // WB Stage inputs
    reg [4:0]  wb_rd_addr;
    reg        wb_reg_write;
    reg [31:0] wb_result;

    // Control inputs
    reg        branch_taken;
    reg        jump_taken;

    // Outputs
    wire       stall_if;
    wire       stall_id;
    wire       flush_if;
    wire       flush_id;
    wire       flush_ex;
    wire [1:0] fwd_alu_a;
    wire [1:0] fwd_alu_b;
    wire [31:0] fwd_ex_result;
    wire [31:0] fwd_mem_result;
    wire [31:0] fwd_wb_result;

    // Test tracking
    integer errors;
    integer test_num;

    // Instantiate DUT
    hazard_unit u_dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .id_rs1_addr    (id_rs1_addr),
        .id_rs2_addr    (id_rs2_addr),
        .id_branch      (id_branch),
        .id_jump        (id_jump),
        .id_jr          (id_jr),
        .ex_rd_addr     (ex_rd_addr),
        .ex_mem_read    (ex_mem_read),
        .ex_reg_write   (ex_reg_write),
        .ex_result      (ex_result),
        .mem_rd_addr    (mem_rd_addr),
        .mem_reg_write  (mem_reg_write),
        .mem_result     (mem_result),
        .wb_rd_addr     (wb_rd_addr),
        .wb_reg_write   (wb_reg_write),
        .wb_result      (wb_result),
        .branch_taken   (branch_taken),
        .jump_taken     (jump_taken),
        .stall_if       (stall_if),
        .stall_id       (stall_id),
        .flush_if       (flush_if),
        .flush_id       (flush_id),
        .flush_ex       (flush_ex),
        .fwd_alu_a      (fwd_alu_a),
        .fwd_alu_b      (fwd_alu_b),
        .fwd_ex_result  (fwd_ex_result),
        .fwd_mem_result (fwd_mem_result),
        .fwd_wb_result  (fwd_wb_result)
    );

    // Generate waveform
    initial begin
        $dumpfile("hazard_unit_tb.vcd");
        $dumpvars(0, tb_hazard_unit);
    end

    // Clock generation (10ns period)
    always #5 clk = ~clk;

    // Helper: Apply default (all-zero) inputs
    task apply_defaults;
        begin
            id_rs1_addr   = 5'd0;
            id_rs2_addr   = 5'd0;
            id_branch     = 1'b0;
            id_jump       = 1'b0;
            id_jr         = 1'b0;
            ex_rd_addr    = 5'd0;
            ex_mem_read   = 1'b0;
            ex_reg_write  = 1'b0;
            ex_result     = 32'd0;
            mem_rd_addr   = 5'd0;
            mem_reg_write = 1'b0;
            mem_result    = 32'd0;
            wb_rd_addr    = 5'd0;
            wb_reg_write  = 1'b0;
            wb_result     = 32'd0;
            branch_taken  = 1'b0;
            jump_taken    = 1'b0;
        end
    endtask

    // Helper: Check outputs against expected values
    task check_outputs;
        input string test_name;
        input exp_stall_if;
        input exp_stall_id;
        input exp_flush_if;
        input exp_flush_id;
        input exp_flush_ex;
        input [1:0] exp_fwd_a;
        input [1:0] exp_fwd_b;
        input [31:0] exp_fwd_ex;
        input [31:0] exp_fwd_mem;
        input [31:0] exp_fwd_wb;
        begin
            if (stall_if !== exp_stall_if) begin
                $display("[%0s] ERROR: stall_if = %b, expected %b", test_name, stall_if, exp_stall_if);
                errors = errors + 1;
            end
            if (stall_id !== exp_stall_id) begin
                $display("[%0s] ERROR: stall_id = %b, expected %b", test_name, stall_id, exp_stall_id);
                errors = errors + 1;
            end
            if (flush_if !== exp_flush_if) begin
                $display("[%0s] ERROR: flush_if = %b, expected %b", test_name, flush_if, exp_flush_if);
                errors = errors + 1;
            end
            if (flush_id !== exp_flush_id) begin
                $display("[%0s] ERROR: flush_id = %b, expected %b", test_name, flush_id, exp_flush_id);
                errors = errors + 1;
            end
            if (flush_ex !== exp_flush_ex) begin
                $display("[%0s] ERROR: flush_ex = %b, expected %b", test_name, flush_ex, exp_flush_ex);
                errors = errors + 1;
            end
            if (fwd_alu_a !== exp_fwd_a) begin
                $display("[%0s] ERROR: fwd_alu_a = %b, expected %b", test_name, fwd_alu_a, exp_fwd_a);
                errors = errors + 1;
            end
            if (fwd_alu_b !== exp_fwd_b) begin
                $display("[%0s] ERROR: fwd_alu_b = %b, expected %b", test_name, fwd_alu_b, exp_fwd_b);
                errors = errors + 1;
            end
            if (fwd_ex_result !== exp_fwd_ex) begin
                $display("[%0s] ERROR: fwd_ex_result = %h, expected %h", test_name, fwd_ex_result, exp_fwd_ex);
                errors = errors + 1;
            end
            if (fwd_mem_result !== exp_fwd_mem) begin
                $display("[%0s] ERROR: fwd_mem_result = %h, expected %h", test_name, fwd_mem_result, exp_fwd_mem);
                errors = errors + 1;
            end
            if (fwd_wb_result !== exp_fwd_wb) begin
                $display("[%0s] ERROR: fwd_wb_result = %h, expected %h", test_name, fwd_wb_result, exp_fwd_wb);
                errors = errors + 1;
            end
        end
    endtask

    // Main test sequence
    initial begin
        // Initialize
        clk = 1'b0;
        rst_n = 1'b0;
        errors = 0;
        test_num = 0;

        // Apply reset
        apply_defaults();
        #20 rst_n = 1'b1;
        #5; // small delay

        $display("============================================");
        $display("Starting Hazard Unit Testbench");
        $display("============================================");

        // -------------------------------------------------------------
        // Test 1: Reset / default state
        // -------------------------------------------------------------
        test_num = 1;
        apply_defaults();
        #1;
        check_outputs("Test01_Default",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                       2'b00, 2'b00,
                       32'd0, 32'd0, 32'd0);
        $display("[Test%0d] Default state after reset - passed", test_num);

        // -------------------------------------------------------------
        // Test 2: Load-Use Hazard (RS1 matches EX.Rd)
        // -------------------------------------------------------------
        test_num = 2;
        apply_defaults();
        ex_mem_read  = 1'b1;
        ex_reg_write = 1'b1;
        ex_rd_addr   = 5'd1;
        id_rs1_addr  = 5'd1;
        id_rs2_addr  = 5'd0;
        // Data values irrelevant for stall, but test forwarding data at 0
        ex_result     = 32'hDEAD0001;
        mem_result    = 32'hBEEF0002;
        wb_result     = 32'hCAFE0003;
        #1;
        // Load-use hazard active -> stall_if=1, stall_id=1, fwds disabled
        check_outputs("Test02_LoadUse_RS1",
                       1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
                       2'b00, 2'b00,
                       ex_result, mem_result, wb_result);
        $display("[Test%0d] Load-Use Hazard (RS1 match) - passed", test_num);

        // -------------------------------------------------------------
        // Test 3: Load-Use Hazard (RS2 matches EX.Rd)
        // -------------------------------------------------------------
        test_num = 3;
        apply_defaults();
        ex_mem_read  = 1'b1;
        ex_reg_write = 1'b1;
        ex_rd_addr   = 5'd2;
        id_rs1_addr  = 5'd0;
        id_rs2_addr  = 5'd2;
        ex_result     = 32'hA5A5_1111;
        #1;
        check_outputs("Test03_LoadUse_RS2",
                       1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
                       2'b00, 2'b00,
                       ex_result, mem_result, wb_result);
        $display("[Test%0d] Load-Use Hazard (RS2 match) - passed", test_num);

        // -------------------------------------------------------------
        // Test 4: Load-Use Hazard with EX.Rd = 0 (no stall)
        // -------------------------------------------------------------
        test_num = 4;
        apply_defaults();
        ex_mem_read  = 1'b1;
        ex_reg_write = 1'b1;
        ex_rd_addr   = 5'd0;   // Rd=0, so no hazard
        id_rs1_addr  = 5'd1;
        id_rs2_addr  = 5'd0;
        #1;
        check_outputs("Test04_LoadUse_Rd0",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                       2'b00, 2'b00,
                       32'd0, 32'd0, 32'd0);
        $display("[Test%0d] Load-Use with Rd=0 (no stall) - passed", test_num);

        // -------------------------------------------------------------
        // Test 5: Branch taken -> flush_if=1, flush_id=1
        // -------------------------------------------------------------
        test_num = 5;
        apply_defaults();
        branch_taken = 1'b1;
        jump_taken   = 1'b0;
        // No load hazard, so forwarding should work if conditions met.
        // For simplicity, check flush bits only; set some forwarding condition separately.
        // Here fwd_alu should be 00 as no forwarding matches.
        #1;
        check_outputs("Test05_Branch",
                       1'b0, 1'b0, 1'b1, 1'b1, 1'b0,
                       2'b00, 2'b00,
                       32'd0, 32'd0, 32'd0);
        $display("[Test%0d] Branch taken flush signals - passed", test_num);

        // -------------------------------------------------------------
        // Test 6: Jump taken -> flush_if=1, flush_id=0
        // -------------------------------------------------------------
        test_num = 6;
        apply_defaults();
        branch_taken = 1'b0;
        jump_taken   = 1'b1;
        #1;
        check_outputs("Test06_Jump",
                       1'b0, 1'b0, 1'b1, 1'b0, 1'b0,
                       2'b00, 2'b00,
                       32'd0, 32'd0, 32'd0);
        $display("[Test%0d] Jump taken flush signals - passed", test_num);

        // -------------------------------------------------------------
        // Test 7: Both branch and jump taken (flush_if=1, flush_id=1)
        // -------------------------------------------------------------
        test_num = 7;
        apply_defaults();
        branch_taken = 1'b1;
        jump_taken   = 1'b1;
        #1;
        check_outputs("Test07_BranchJump",
                       1'b0, 1'b0, 1'b1, 1'b1, 1'b0,
                       2'b00, 2'b00,
                       32'd0, 32'd0, 32'd0);
        $display("[Test%0d] Both branch and jump taken - passed", test_num);

        // -------------------------------------------------------------
        // Test 8: EX forwarding for RS1 (fwd_alu_a = 11)
        // -------------------------------------------------------------
        test_num = 8;
        apply_defaults();
        ex_reg_write = 1'b1;
        ex_rd_addr   = 5'd3;
        id_rs1_addr  = 5'd3;
        ex_result    = 32'h1234_5678;
        mem_result   = 32'hFEED_0000;
        wb_result    = 32'hDEAD_BEEF;
        #1;
        check_outputs("Test08_EX_Fwd_A",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                       2'b11, 2'b00,
                       ex_result, mem_result, wb_result);
        $display("[Test%0d] EX forwarding for operand A - passed", test_num);

        // -------------------------------------------------------------
        // Test 9: EX forwarding for RS2 (fwd_alu_b = 11)
        // -------------------------------------------------------------
        test_num = 9;
        apply_defaults();
        ex_reg_write = 1'b1;
        ex_rd_addr   = 5'd4;
        id_rs1_addr  = 5'd0;
        id_rs2_addr  = 5'd4;
        ex_result    = 32'hA5A5_5A5A;
        #1;
        check_outputs("Test09_EX_Fwd_B",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                       2'b00, 2'b11,
                       ex_result, mem_result, wb_result);
        $display("[Test%0d] EX forwarding for operand B - passed", test_num);

        // -------------------------------------------------------------
        // Test 10: MEM forwarding for RS1 (no EX match)
        // -------------------------------------------------------------
        test_num = 10;
        apply_defaults();
        ex_reg_write = 1'b0;
        mem_reg_write = 1'b1;
        mem_rd_addr   = 5'd5;
        id_rs1_addr   = 5'd5;
        mem_result    = 32'hBEEF_CAFE;
        ex_result     = 32'h1111_2222; // different
        #1;
        check_outputs("Test10_MEM_Fwd_A",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                       2'b01, 2'b00,
                       ex_result, mem_result, wb_result);
        $display("[Test%0d] MEM forwarding for operand A - passed", test_num);

        // -------------------------------------------------------------
        // Test 11: WB forwarding for RS1 (no EX/MEM match)
        // -------------------------------------------------------------
        test_num = 11;
        apply_defaults();
        ex_reg_write  = 1'b0;
        mem_reg_write = 1'b0;
        wb_reg_write  = 1'b1;
        wb_rd_addr    = 5'd6;
        id_rs1_addr   = 5'd6;
        wb_result     = 32'hDEAD_0001;
        #1;
        check_outputs("Test11_WB_Fwd_A",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                       2'b10, 2'b00,
                       32'd0, 32'd0, wb_result);
        $display("[Test%0d] WB forwarding for operand A - passed", test_num);

        // -------------------------------------------------------------
        // Test 12: Priority EX > MEM (both match RS1)
        // -------------------------------------------------------------
        test_num = 12;
        apply_defaults();
        ex_reg_write  = 1'b1;
        mem_reg_write = 1'b1;
        ex_rd_addr    = 5'd7;
        mem_rd_addr   = 5'd7;
        id_rs1_addr   = 5'd7;
        ex_result     = 32'hAAAA_BBBB;
        mem_result    = 32'hCCCC_DDDD;
        #1;
        // EX should win, fwd_alu_a = 11
        check_outputs("Test12_Priority_EX_MEM",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                       2'b11, 2'b00,
                       ex_result, mem_result, wb_result);
        $display("[Test%0d] Priority EX over MEM - passed", test_num);

        // -------------------------------------------------------------
        // Test 13: Priority EX > WB (both match RS1)
        // -------------------------------------------------------------
        test_num = 13;
        apply_defaults();
        ex_reg_write  = 1'b1;
        wb_reg_write  = 1'b1;
        ex_rd_addr    = 5'd8;
        wb_rd_addr    = 5'd8;
        id_rs1_addr   = 5'd8;
        ex_result     = 32'h1111_EEEE;
        wb_result     = 32'h2222_FFFF;
        #1;
        check_outputs("Test13_Priority_EX_WB",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                       2'b11, 2'b00,
                       ex_result, mem_result, wb_result);
        $display("[Test%0d] Priority EX over WB - passed", test_num);

        // -------------------------------------------------------------
        // Test 14: MEM vs WB priority (MEM wins)
        // -------------------------------------------------------------
        test_num = 14;
        apply_defaults();
        ex_reg_write  = 1'b0;
        mem_reg_write = 1'b1;
        wb_reg_write  = 1'b1;
        mem_rd_addr   = 5'd9;
        wb_rd_addr    = 5'd9;
        id_rs1_addr   = 5'd9;
        mem_result    = 32'h3333_AAAA;
        wb_result     = 32'h4444_BBBB;
        #1;
        // MEM should win, fwd_alu_a = 01
        check_outputs("Test14_Priority_MEM_WB",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                       2'b01, 2'b00,
                       ex_result, mem_result, wb_result);
        $display("[Test%0d] Priority MEM over WB - passed", test_num);

        // -------------------------------------------------------------
        // Test 15: Stall overrides forwarding
        // -------------------------------------------------------------
        test_num = 15;
        apply_defaults();
        // Setup load-use hazard
        ex_mem_read   = 1'b1;
        ex_reg_write  = 1'b1;
        ex_rd_addr    = 5'd10;
        id_rs1_addr   = 5'd10;
        // Also setup EX forwarding condition (which would otherwise give fwd_alu_a=11)
        ex_result     = 32'hF00F_F00F;
        #1;
        // Stall active -> fwd_alu_a = 00
        check_outputs("Test15_StallOverridesFwd",
                       1'b1, 1'b1, 1'b0, 1'b0, 1'b0,
                       2'b00, 2'b00,
                       ex_result, mem_result, wb_result);
        $display("[Test%0d] Stall overrides forwarding - passed", test_num);

        // -------------------------------------------------------------
        // Test 16: Data pass-through (vary results)
        // -------------------------------------------------------------
        test_num = 16;
        apply_defaults();
        ex_result  = 32'hDEAD0001;
        mem_result = 32'hBEEF0002;
        wb_result  = 32'hCAFE0003;
        #1;
        if (fwd_ex_result !== ex_result ||
            fwd_mem_result !== mem_result ||
            fwd_wb_result !== wb_result) begin
            $display("[Test%0d] Data pass-through FAILED", test_num);
            errors = errors + 1;
        end else
            $display("[Test%0d] Data pass-through - passed", test_num);

        // -------------------------------------------------------------
        // Test 17: Simultaneous A and B forwarding from different stages
        // -------------------------------------------------------------
        test_num = 17;
        apply_defaults();
        // A from EX, B from MEM
        ex_reg_write  = 1'b1;
        ex_rd_addr    = 5'd11;
        id_rs1_addr   = 5'd11;
        ex_result     = 32'hAAAA_AAAA;
        // B from MEM (no EX match on B)
        mem_reg_write = 1'b1;
        mem_rd_addr   = 5'd12;
        id_rs2_addr   = 5'd12;
        mem_result    = 32'hBBBB_BBBB;
        // WB not used
        wb_reg_write  = 1'b0;
        #1;
        check_outputs("Test17_MixedFwd",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                       2'b11, 2'b01,  // A=EX, B=MEM
                       ex_result, mem_result, wb_result);
        $display("[Test%0d] Mixed forwarding (EX for A, MEM for B) - passed", test_num);

        // -------------------------------------------------------------
        // Test 18: Rd address zero does not trigger forwarding
        // -------------------------------------------------------------
        test_num = 18;
        apply_defaults();
        ex_reg_write = 1'b1;
        ex_rd_addr   = 5'd0;   // Rd=0
        id_rs1_addr  = 5'd1;
        id_rs2_addr  = 5'd2;
        ex_result    = 32'h12345678;
        #1;
        check_outputs("Test18_Rd0_NoFwd",
                       1'b0, 1'b0, 1'b0, 1'b0, 1'b0,
                       2'b00, 2'b00,
                       ex_result, mem_result, wb_result);
        $display("[Test%0d] Rd=0 no forwarding - passed", test_num);

        // -------------------------------------------------------------
        // Final result
        // -------------------------------------------------------------
        $display("============================================");
        if (errors == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED with %0d errors", errors);
        end
        $display("============================================");
        $finish;
    end

endmodule