`timescale 1ns/1ps

module tb_alu;

    // DUT inputs
    reg [31:0] a;
    reg [31:0] b;
    reg [3:0] op;

    // DUT outputs
    wire [31:0] result;
    wire zero;

    // Instantiate the ALU
    alu uut (
        .a(a),
        .b(b),
        .op(op),
        .result(result),
        .zero(zero)
    );

    // Test status tracking
    integer error_count;

    // Waveform generation
    initial begin
        $dumpfile("alu_tb.vcd");
        $dumpvars(0, tb_alu);
    end

    // Task to apply stimulus and check results
    task check_alu;
        input [31:0] stim_a;
        input [31:0] stim_b;
        input [3:0] stim_op;
        input [31:0] expected_result;
        input expected_zero;
        input [512:1] test_name; // sufficient for description

        begin
            a = stim_a;
            b = stim_b;
            op = stim_op;
            #1; // allow combinational propagation

            // Compare actual vs expected
            if (result !== expected_result || zero !== expected_zero) begin
                $display("[FAIL] %s", test_name);
                $display("        Expected: result=0x%h zero=%0b", expected_result, expected_zero);
                $display("        Got:      result=0x%h zero=%0b", result, zero);
                error_count = error_count + 1;
            end else begin
                $display("[PASS] %s", test_name);
            end
        end
    endtask

    // Main test sequence
    initial begin
        error_count = 0;
        $display("========================================");
        $display(" Starting ALU Comprehensive Testbench");
        $display("========================================");

        // ---------- ADD (op=0) ----------
        check_alu(32'd10, 32'd5, 4'd0, 32'd15, 1'b0, "ADD: 10 + 5 = 15");
        check_alu(32'hFFFFFFFF, 32'd1, 4'd0, 32'd0, 1'b1, "ADD: 0xFFFFFFFF + 1 = 0 (overflow, zero=1)");
        check_alu(32'd0, 32'd0, 4'd0, 32'd0, 1'b1, "ADD: 0+0 -> zero=1");

        // ---------- SUB (op=1) ----------
        check_alu(32'd10, 32'd5, 4'd1, 32'd5, 1'b0, "SUB: 10 - 5 = 5");
        check_alu(32'd5, 32'd5, 4'd1, 32'd0, 1'b1, "SUB: 5-5 -> zero=1");
        check_alu(32'h80000000, 32'd1, 4'd1, 32'h7FFFFFFF, 1'b0, "SUB: 0x80000000 - 1 = 0x7FFFFFFF");

        // ---------- SLL (op=2) ----------
        check_alu(32'd1, 32'd4, 4'd2, 32'd16, 1'b0, "SLL: 1 << 4 = 16");
        check_alu(32'd5, 32'd0, 4'd2, 32'd5, 1'b0, "SLL: 5 << 0 = 5");
        check_alu(32'd1, 32'd31, 4'd2, 32'h80000000, 1'b0, "SLL: 1 << 31 = 0x80000000");
        check_alu(32'hF, 32'd2, 4'd2, 32'h3C, 1'b0, "SLL: 0xF << 2 = 0x3C");

        // ---------- SLT signed (op=3) ----------
        // -2 < -1  → true
        check_alu(32'hFFFFFFFE, 32'hFFFFFFFF, 4'd3, 32'd1, 1'b0, "SLT: -2 < -1 → 1");
        // -1 < -2  → false
        check_alu(32'hFFFFFFFF, 32'hFFFFFFFE, 4'd3, 32'd0, 1'b0, "SLT: -1 < -2 → 0");
        // 5 < 6    → true
        check_alu(32'd5, 32'd6, 4'd3, 32'd1, 1'b0, "SLT: 5 < 6 → 1");
        // 0 < 0    → false
        check_alu(32'd0, 32'd0, 4'd3, 32'd0, 1'b0, "SLT: 0 < 0 → 0");

        // ---------- SLTU unsigned (op=4) ----------
        check_alu(32'h80000000, 32'h7FFFFFFF, 4'd4, 32'd0, 1'b0, "SLTU: 0x80000000 < 0x7FFFFFFF → 0");
        check_alu(32'h7FFFFFFF, 32'h80000000, 4'd4, 32'd1, 1'b0, "SLTU: 0x7FFFFFFF < 0x80000000 → 1");
        check_alu(32'd5, 32'd10, 4'd4, 32'd1, 1'b0, "SLTU: 5 < 10 → 1");

        // ---------- XOR (op=5) ----------
        check_alu(32'hAA, 32'h55, 4'd5, 32'hFF, 1'b0, "XOR: 0xAA ^ 0x55 = 0xFF");
        check_alu(32'hFFFFFFFF, 32'h0, 4'd5, 32'hFFFFFFFF, 1'b0, "XOR: 0xFFFFFFFF ^ 0 = 0xFFFFFFFF");
        check_alu(32'h0, 32'h0, 4'd5, 32'd0, 1'b1, "XOR: 0 ^ 0 = 0 (zero)");

        // ---------- SRL logical (op=6) ----------
        check_alu(32'hF0000000, 32'd4, 4'd6, 32'h0F000000, 1'b0, "SRL: 0xF0000000 >> 4 = 0x0F000000");
        check_alu(32'h0000FF00, 32'd0, 4'd6, 32'h0000FF00, 1'b0, "SRL: 0x0000FF00 >> 0 = same");
        check_alu(32'hFFFFFFFF, 32'd31, 4'd6, 32'h00000001, 1'b0, "SRL: 0xFFFFFFFF >> 31 = 1");

        // ---------- SRA arithmetic (op=7) ----------
        // -2 (0xFFFFFFFE) shifted right by 1 → 0xFFFFFFFF
        check_alu(32'hFFFFFFFE, 32'd1, 4'd7, 32'hFFFFFFFF, 1'b0, "SRA: -2 >>> 1 = 0xFFFFFFFF");
        // 0x80000000 (most negative) >>> 31 = 0xFFFFFFFF
        check_alu(32'h80000000, 32'd31, 4'd7, 32'hFFFFFFFF, 1'b0, "SRA: 0x80000000 >>> 31 = 0xFFFFFFFF");
        // Positive number arithmetic shift
        check_alu(32'h0F000000, 32'd4, 4'd7, 32'h00F00000, 1'b0, "SRA: 0x0F000000 >>> 4 = 0x00F00000");

        // ---------- OR (op=8) ----------
        check_alu(32'h0F0F0F0F, 32'hF0F0F0F0, 4'd8, 32'hFFFFFFFF, 1'b0, "OR: 0x0F0F0F0F | 0xF0F0F0F0 = 0xFFFFFFFF");
        check_alu(32'h0, 32'h0, 4'd8, 32'd0, 1'b1, "OR: 0 | 0 → zero=1");

        // ---------- AND (op=9) ----------
        check_alu(32'h0F0F0F0F, 32'hF0F0F0F0, 4'd9, 32'd0, 1'b1, "AND: 0x0F0F0F0F & 0xF0F0F0F0 = 0 (zero)");
        check_alu(32'hFFFFFFFF, 32'hFFFFFFFF, 4'd9, 32'hFFFFFFFF, 1'b0, "AND: 0xFFFFFFFF & 0xFFFFFFFF = 0xFFFFFFFF");

        // ---------- Default operation (undefined opcode) ----------
        check_alu(32'd123, 32'd456, 4'd10, 32'd0, 1'b1, "Default: op=10 → result=0 (zero=1)");
        check_alu(32'd1, 32'd2, 4'd15, 32'd0, 1'b1, "Default: op=15 → result=0 (zero=1)");

        // ---------- Final report ----------
        $display("========================================");
        if (error_count == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED with %0d errors", error_count);
        end
        $display("========================================");
        $finish;
    end

endmodule