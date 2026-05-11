`timescale 1ns/1ps
module tb_imm_gen;

    // Inputs/outputs
    reg  [31:0] instr;
    wire [31:0] imm;

    // Instantiate DUT
    imm_gen dut (
        .instr(instr),
        .imm  (imm)
    );

    // Waveform dump
    initial begin
        $dumpfile("imm_gen_tb.vcd");
        $dumpvars(0, tb_imm_gen);
    end

    // Reference model: repeats the RTL logic exactly
    function [31:0] expected_imm;
        input [31:0] instr;
        reg [6:2] opcode;
        reg [31:0] i_imm, s_imm, b_imm, u_imm, j_imm;
        begin
            opcode = instr[6:2];
            i_imm  = {{20{instr[31]}}, instr[31:20]};
            s_imm  = {{20{instr[31]}}, instr[31:25], instr[11:7]};
            b_imm  = {{19{instr[31]}}, instr[31], instr[7],
                      instr[30:25], instr[11:8], 1'b0};
            u_imm  = {instr[31:12], 12'b0};
            j_imm  = {{11{instr[31]}}, instr[31], instr[19:12],
                      instr[20], instr[30:21], 1'b0};

            case (opcode)
                5'b00000: expected_imm = i_imm;   // Load (I-type)
                5'b00100: expected_imm = i_imm;   // I-arithmetic
                5'b01100: expected_imm = i_imm;   // OP-IMM (I-type)
                5'b01000: expected_imm = s_imm;   // Store (S-type)
                5'b11000: expected_imm = b_imm;   // Branch (B-type)
                5'b01101: expected_imm = u_imm;   // LUI (U-type)
                5'b00101: expected_imm = u_imm;   // AUIPC (U-type)
                5'b11011: expected_imm = j_imm;   // JAL (J-type)
                default:  expected_imm = 32'b0;
            endcase
        end
    endfunction

    integer errors;

    task run_test;
        input [31:0] instr_val;
        begin
            instr = instr_val;
            #5;
            if (imm !== expected_imm(instr_val)) begin
                $display("ERROR: instr=%h, imm=%h, expected=%h",
                         instr, imm, expected_imm(instr_val));
                errors = errors + 1;
            end else begin
                $display("OK:    instr=%h -> imm=%h", instr, imm);
            end
        end
    endtask

    initial begin
        errors = 0;
        $display("Starting imm_gen testbench...");

        // I-type (load) positive / negative
        run_test(32'h55500003);   // imm12=0x555, sign=0 -> 0x00000555
        run_test(32'hAAA00003);   // imm12=0xAAA, sign=1 -> 0xFFFFFAAA

        // I-type (arithmetic) max pos / max neg
        run_test(32'h7FF00013);   // imm12=0x7FF, sign=0 -> 0x000007FF
        run_test(32'h80000013);   // imm12=0x800, sign=1 -> 0xFFFFF800

        // I-type (OP-IMM) positive / negative
        run_test(32'h12300033);   // imm12=0x123, sign=0 -> 0x00000123
        run_test(32'hF0000033);   // imm12=0xF00, sign=1 -> 0xFFFFFF00

        // I-type with opcode bits[1:0]=00 (still 5'b00000)
        run_test(32'h12300000);

        // I-type with different opcode bits[1:0]=01 (still 5'b00000)
        run_test(32'hFFF00001);   // imm12=0xFFF -> 0xFFFFFFFF

        // S-type all zero
        run_test(32'h00000023);   // imm=0

        // S-type positive / negative
        run_test(32'h54000CA3);   // {7'h2A,5'h19} -> 0x00000559
        run_test(32'hD4000AA3);   // {7'h6A,5'h15}, sign=1 -> 0xFFFFFD55

        // S-type max positive (imm12=0x7FF, sign=0)
        run_test(32'h7E000FA3);   // -> 0x000007FF

        // B-type all zero
        run_test(32'h00000063);   // imm=0

        // B-type positive / negative
        run_test(32'h54000CE3);   // {0,1,6'h2A,4'hC,1'b0} -> 0x00000D58
        run_test(32'h80000063);   // sign=1 -> 0xFFFFF800

        // B-type max positive
        run_test(32'h7E000FE3);   // {0,1,6'h3F,4'hF,1'b0} -> 0x00000FFE

        // U-type LUI positive / all ones
        run_test(32'hAAAAA037);   // 0xAAAAA000
        run_test(32'hFFFFF037);   // 0xFFFFF000

        // U-type AUIPC
        run_test(32'h55555017);   // 0x55555000

        // J-type positive / negative
        run_test(32'h2ABA506F);   // -> 0x000A5AAA
        run_test(32'h8000006F);   // sign=1 -> 0xFFF00000

        // J-type max positive / max negative (with sign)
        run_test(32'h7FFFF06F);   // -> 0x000FFFFE
        run_test(32'hFFFFF06F);   // sign=1 -> 0xFFFFFFFE

        // Default (unrecognized opcode) should output 0
        run_test(32'hFFFFFFFF);   // opcode 7'b1111111
        run_test(32'h12300004);   // opcode 7'b0000100

        // Final verdict
        if (errors == 0) begin
            $display("TEST PASSED");
        end else begin
            $display("TEST FAILED with %0d errors", errors);
        end
        $stop;
    end

endmodule