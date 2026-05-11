`timescale 1ns/1ps

module tb_control_unit;

    // DUT inputs
    reg  [31:0] instr;
    // DUT outputs
    wire        alu_src;
    wire [3:0]  alu_op;
    wire        mem_read;
    wire        mem_write;
    wire        reg_write;
    wire [1:0]  wb_sel;
    wire        branch;
    wire        jump;
    wire        jr;
    wire        is_load;
    wire        is_store;
    wire [2:0]  funct3;

    // Instantiate the Unit Under Test (UUT)
    control_unit dut (
        .instr     (instr),
        .alu_src   (alu_src),
        .alu_op    (alu_op),
        .mem_read  (mem_read),
        .mem_write (mem_write),
        .reg_write (reg_write),
        .wb_sel    (wb_sel),
        .branch    (branch),
        .jump      (jump),
        .jr        (jr),
        .is_load   (is_load),
        .is_store  (is_store),
        .funct3    (funct3)
    );

    integer errors = 0;

    // Helper task: apply stimulus and check all outputs
    task automatic check_outputs;
        input [31:0] instr_val;
        input string test_name;
        input        exp_alu_src;
        input [3:0]  exp_alu_op;
        input        exp_mem_read;
        input        exp_mem_write;
        input        exp_reg_write;
        input [1:0]  exp_wb_sel;
        input        exp_branch;
        input        exp_jump;
        input        exp_jr;
        input        exp_is_load;
        input        exp_is_store;
        begin
            instr = instr_val;
            #1;  // let combinational logic settle

            // Check alu_src
            if (alu_src !== exp_alu_src) begin
                $display("FAIL [%s] alu_src: got %b, expected %b", test_name, alu_src, exp_alu_src);
                errors = errors + 1;
            end
            // Check alu_op
            if (alu_op !== exp_alu_op) begin
                $display("FAIL [%s] alu_op: got %b, expected %b", test_name, alu_op, exp_alu_op);
                errors = errors + 1;
            end
            // Check mem_read
            if (mem_read !== exp_mem_read) begin
                $display("FAIL [%s] mem_read: got %b, expected %b", test_name, mem_read, exp_mem_read);
                errors = errors + 1;
            end
            // Check mem_write
            if (mem_write !== exp_mem_write) begin
                $display("FAIL [%s] mem_write: got %b, expected %b", test_name, mem_write, exp_mem_write);
                errors = errors + 1;
            end
            // Check reg_write
            if (reg_write !== exp_reg_write) begin
                $display("FAIL [%s] reg_write: got %b, expected %b", test_name, reg_write, exp_reg_write);
                errors = errors + 1;
            end
            // Check wb_sel
            if (wb_sel !== exp_wb_sel) begin
                $display("FAIL [%s] wb_sel: got %b, expected %b", test_name, wb_sel, exp_wb_sel);
                errors = errors + 1;
            end
            // Check branch
            if (branch !== exp_branch) begin
                $display("FAIL [%s] branch: got %b, expected %b", test_name, branch, exp_branch);
                errors = errors + 1;
            end
            // Check jump
            if (jump !== exp_jump) begin
                $display("FAIL [%s] jump: got %b, expected %b", test_name, jump, exp_jump);
                errors = errors + 1;
            end
            // Check jr
            if (jr !== exp_jr) begin
                $display("FAIL [%s] jr: got %b, expected %b", test_name, jr, exp_jr);
                errors = errors + 1;
            end
            // Check is_load
            if (is_load !== exp_is_load) begin
                $display("FAIL [%s] is_load: got %b, expected %b", test_name, is_load, exp_is_load);
                errors = errors + 1;
            end
            // Check is_store
            if (is_store !== exp_is_store) begin
                $display("FAIL [%s] is_store: got %b, expected %b", test_name, is_store, exp_is_store);
                errors = errors + 1;
            end
            // Check funct3 passthrough
            if (funct3 !== instr_val[14:12]) begin
                $display("FAIL [%s] funct3: got %b, expected %b", test_name, funct3, instr_val[14:12]);
                errors = errors + 1;
            end

            if (alu_src === exp_alu_src &&
                alu_op  === exp_alu_op &&
                mem_read  === exp_mem_read &&
                mem_write === exp_mem_write &&
                reg_write === exp_reg_write &&
                wb_sel    === exp_wb_sel &&
                branch    === exp_branch &&
                jump      === exp_jump &&
                jr        === exp_jr &&
                is_load   === exp_is_load &&
                is_store  === exp_is_store &&
                funct3    === instr_val[14:12]) begin
                $display("PASS [%s]", test_name);
            end
        end
    endtask

    initial begin
        $dumpfile("control_unit_tb.vcd");
        $dumpvars(0, tb_control_unit);

        $display("------------------------------");
        $display(" Starting control unit tests ");
        $display("------------------------------");

        //--------------------------------------------------------------
        // 1. R-type (OP) instructions
        //--------------------------------------------------------------
        // ADD: funct3=000, funct7_bit5=0 -> alu_op=0000
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b000, 5'b0, 7'b0110011},
            "R-ADD",
            .exp_alu_src(1'b0), .exp_alu_op(4'b0000), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // SUB: funct3=000, funct7_bit5=1 -> alu_op=0001
        check_outputs(
            {7'b0100000, 5'b0, 5'b0, 3'b000, 5'b0, 7'b0110011},
            "R-SUB",
            .exp_alu_src(1'b0), .exp_alu_op(4'b0001), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // SLL: funct3=001 -> alu_op=0010
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b001, 5'b0, 7'b0110011},
            "R-SLL",
            .exp_alu_src(1'b0), .exp_alu_op(4'b0010), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // SLT: funct3=010 -> alu_op=0011
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b010, 5'b0, 7'b0110011},
            "R-SLT",
            .exp_alu_src(1'b0), .exp_alu_op(4'b0011), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // SLTU: funct3=011 -> alu_op=0100
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b011, 5'b0, 7'b0110011},
            "R-SLTU",
            .exp_alu_src(1'b0), .exp_alu_op(4'b0100), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // XOR: funct3=100 -> alu_op=0101
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b100, 5'b0, 7'b0110011},
            "R-XOR",
            .exp_alu_src(1'b0), .exp_alu_op(4'b0101), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // SRL: funct3=101, funct7_bit5=0 -> alu_op=0110
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b101, 5'b0, 7'b0110011},
            "R-SRL",
            .exp_alu_src(1'b0), .exp_alu_op(4'b0110), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // SRA: funct3=101, funct7_bit5=1 -> alu_op=0111
        check_outputs(
            {7'b0100000, 5'b0, 5'b0, 3'b101, 5'b0, 7'b0110011},
            "R-SRA",
            .exp_alu_src(1'b0), .exp_alu_op(4'b0111), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // OR: funct3=110 -> alu_op=1000
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b110, 5'b0, 7'b0110011},
            "R-OR",
            .exp_alu_src(1'b0), .exp_alu_op(4'b1000), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // AND: funct3=111 -> alu_op=1001
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b111, 5'b0, 7'b0110011},
            "R-AND",
            .exp_alu_src(1'b0), .exp_alu_op(4'b1001), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        //--------------------------------------------------------------
        // 2. I-type (OP-IMM) instructions
        //--------------------------------------------------------------
        // ADDI: funct3=000 -> alu_op=0000, alu_src=1
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b000, 5'b0, 7'b0010011},
            "I-ADDI",
            .exp_alu_src(1'b1), .exp_alu_op(4'b0000), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // SLLI: funct3=001 -> alu_op=0010
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b001, 5'b0, 7'b0010011},
            "I-SLLI",
            .exp_alu_src(1'b1), .exp_alu_op(4'b0010), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // SLTI: funct3=010 -> alu_op=0011
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b010, 5'b0, 7'b0010011},
            "I-SLTI",
            .exp_alu_src(1'b1), .exp_alu_op(4'b0011), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // SLTIU: funct3=011 -> alu_op=0100
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b011, 5'b0, 7'b0010011},
            "I-SLTIU",
            .exp_alu_src(1'b1), .exp_alu_op(4'b0100), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // XORI: funct3=100 -> alu_op=0101
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b100, 5'b0, 7'b0010011},
            "I-XORI",
            .exp_alu_src(1'b1), .exp_alu_op(4'b0101), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // SRLI: funct3=101, funct7_bit5=0 -> alu_op=0110
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b101, 5'b0, 7'b0010011},
            "I-SRLI",
            .exp_alu_src(1'b1), .exp_alu_op(4'b0110), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // SRAI: funct3=101, funct7_bit5=1 -> alu_op=0111
        check_outputs(
            {7'b0100000, 5'b0, 5'b0, 3'b101, 5'b0, 7'b0010011},
            "I-SRAI",
            .exp_alu_src(1'b1), .exp_alu_op(4'b0111), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // ORI: funct3=110 -> alu_op=1000
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b110, 5'b0, 7'b0010011},
            "I-ORI",
            .exp_alu_src(1'b1), .exp_alu_op(4'b1000), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        // ANDI: funct3=111 -> alu_op=1001
        check_outputs(
            {7'b0000000, 5'b0, 5'b0, 3'b111, 5'b0, 7'b0010011},
            "I-ANDI",
            .exp_alu_src(1'b1), .exp_alu_op(4'b1001), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        //--------------------------------------------------------------
        // 3. LOAD instructions (opcode 0000011)
        //--------------------------------------------------------------
        check_outputs(
            {7'b0, 5'b0, 5'b0, 3'b010, 5'b0, 7'b0000011}, // LW (funct3=010)
            "LOAD",
            .exp_alu_src(1'b1), .exp_alu_op(4'b0000), .exp_mem_read(1'b1), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b01), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b1), .exp_is_store(1'b0)
        );

        //--------------------------------------------------------------
        // 4. STORE instructions (opcode 0100011)
        //--------------------------------------------------------------
        check_outputs(
            {7'b0, 5'b0, 5'b0, 3'b010, 5'b0, 7'b0100011}, // SW (funct3=010)
            "STORE",
            .exp_alu_src(1'b1), .exp_alu_op(4'b0000), .exp_mem_read(1'b0), .exp_mem_write(1'b1),
            .exp_reg_write(1'b0), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b1)
        );

        //--------------------------------------------------------------
        // 5. BRANCH instructions (opcode 1100011)
        //--------------------------------------------------------------
        check_outputs(
            {7'b0, 5'b0, 5'b0, 3'b000, 5'b0, 7'b1100011}, // BEQ (funct3=000)
            "BRANCH",
            .exp_alu_src(1'b0), .exp_alu_op(4'b0001), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b0), .exp_wb_sel(2'b00), .exp_branch(1'b1), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        //--------------------------------------------------------------
        // 6. JAL instruction (opcode 1101111)
        //--------------------------------------------------------------
        check_outputs(
            {12'b0, 5'b0, 3'b0, 5'b0, 7'b1101111},
            "JAL",
            .exp_alu_src(1'b0), .exp_alu_op(4'b0000), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b10), .exp_branch(1'b0), .exp_jump(1'b1),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        //--------------------------------------------------------------
        // 7. JALR instruction (opcode 1100111)
        //--------------------------------------------------------------
        check_outputs(
            {12'b0, 5'b0, 3'b000, 5'b0, 7'b1100111},
            "JALR",
            .exp_alu_src(1'b1), .exp_alu_op(4'b0000), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b10), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b1), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        //--------------------------------------------------------------
        // 8. LUI instruction (opcode 0110111)
        //--------------------------------------------------------------
        check_outputs(
            {20'b0, 5'b0, 7'b0110111},
            "LUI",
            .exp_alu_src(1'b1), .exp_alu_op(4'b0000), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        //--------------------------------------------------------------
        // 9. AUIPC instruction (opcode 0010111)
        //--------------------------------------------------------------
        check_outputs(
            {20'b0, 5'b0, 7'b0010111},
            "AUIPC",
            .exp_alu_src(1'b1), .exp_alu_op(4'b0000), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        //--------------------------------------------------------------
        // 10. SYSTEM instructions (opcode 1110011) - all defaults
        //--------------------------------------------------------------
        check_outputs(
            {25'b0, 7'b1110011},
            "SYSTEM",
            .exp_alu_src(1'b0), .exp_alu_op(4'b0000), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b0), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        //--------------------------------------------------------------
        // 11. Invalid / undefined opcode (default)
        //--------------------------------------------------------------
        check_outputs(
            {25'b0, 7'b0000000}, // nonexistent opcode
            "INVALID_OPCODE",
            .exp_alu_src(1'b0), .exp_alu_op(4'b0000), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b0), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        //--------------------------------------------------------------
        // 12. funct3 passthrough edge cases
        //--------------------------------------------------------------
        // Verify that funct3 output simply equals instr[14:12] regardless of opcode.
        check_outputs(
            {7'b0, 13'h0, 3'b111, 5'h1F, 7'b0110011}, // R-AND with different funct3
            "FUNCT3=111",
            .exp_alu_src(1'b0), .exp_alu_op(4'b1001), .exp_mem_read(1'b0), .exp_mem_write(1'b0),
            .exp_reg_write(1'b1), .exp_wb_sel(2'b00), .exp_branch(1'b0), .exp_jump(1'b0),
            .exp_jr(1'b0), .exp_is_load(1'b0), .exp_is_store(1'b0)
        );

        //--------------------------------------------------------------
        // Final report
        //--------------------------------------------------------------
        if (errors == 0) begin
            $display("======================================");
            $display("            TEST PASSED                ");
            $display("======================================");
        end else begin
            $display("======================================");
            $display("         TEST FAILED with %0d errors   ", errors);
            $display("======================================");
        end
        $finish;
    end

endmodule