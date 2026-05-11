module control_unit (
    input      [31:0] instr,     // 32-bit instruction
    output reg        alu_src,   // ALU source select (0=rs2, 1=imm)
    output reg [3:0]  alu_op,     // ALU operation code
    output reg        mem_read,  // Memory read enable
    output reg        mem_write, // Memory write enable
    output reg        reg_write, // Register write enable
    output reg [1:0]  wb_sel,     // Write-back select (00=ALU, 01=MEM, 10=PC+4)
    output reg        branch,     // Branch instruction flag
    output reg        jump,      // JAL instruction flag
    output reg        jr,        // JALR instruction flag
    output reg        is_load,   // Is load instruction flag
    output reg        is_store,  // Is store instruction flag
    output wire [2:0] funct3      // funct3 field passthrough
);

    // Internal wires for extracted instruction fields
    wire [6:0] opcode;
    wire [2:0] funct3_wire;
    wire [6:0] funct7;
    wire       funct7_bit5;

    // Extract instruction fields
    assign opcode      = instr[6:0];
    assign funct3_wire = instr[14:12];
    assign funct7      = instr[31:25];
    assign funct7_bit5 = instr[25];
    assign funct3      = funct3_wire;

    // Main decoder - combinational logic
    always @(*) begin
        // Default values to avoid latch inference
        alu_src   = 1'b0;
        alu_op    = 4'b0000;   // Default: ADD
        mem_read  = 1'b0;
        mem_write = 1'b0;
        reg_write = 1'b0;
        wb_sel    = 2'b00;     // Default: ALU result
        branch    = 1'b0;
        jump      = 1'b0;
        jr        = 1'b0;
        is_load   = 1'b0;
        is_store  = 1'b0;

        case (opcode)
            // R-type (OP) instructions
            7'b0110011: begin
                reg_write = 1'b1;
                case (funct3_wire)
                    3'b000: alu_op = funct7_bit5 ? 4'b0001 : 4'b0000;  // SUB or ADD
                    3'b001: alu_op = 4'b0010;  // SLL
                    3'b010: alu_op = 4'b0011;  // SLT
                    3'b011: alu_op = 4'b0100;  // SLTU
                    3'b100: alu_op = 4'b0101;  // XOR
                    3'b101: alu_op = funct7_bit5 ? 4'b0111 : 4'b0110;  // SRA or SRL
                    3'b110: alu_op = 4'b1000;  // OR
                    3'b111: alu_op = 4'b1001;  // AND
                    default: alu_op = 4'b0000;
                endcase
            end

            // I-type (OP-IMM) instructions
            7'b0010011: begin
                reg_write = 1'b1;
                alu_src   = 1'b1;
                case (funct3_wire)
                    3'b000: alu_op = 4'b0000;  // ADDI
                    3'b001: alu_op = 4'b0010;  // SLLI
                    3'b010: alu_op = 4'b0011;  // SLTI
                    3'b011: alu_op = 4'b0100;  // SLTIU
                    3'b100: alu_op = 4'b0101;  // XORI
                    3'b101: alu_op = funct7_bit5 ? 4'b0111 : 4'b0110;  // SRAI or SRLI
                    3'b110: alu_op = 4'b1000;  // ORI
                    3'b111: alu_op = 4'b1001;  // ANDI
                    default: alu_op = 4'b0000;
                endcase
            end

            // LOAD instructions
            7'b0000011: begin
                alu_src   = 1'b1;
                mem_read  = 1'b1;
                reg_write = 1'b1;
                wb_sel    = 2'b01;   // Memory data
                is_load   = 1'b1;
                alu_op    = 4'b0000;  // ADD for address calculation
            end

            // STORE instructions
            7'b0100011: begin
                alu_src   = 1'b1;
                mem_write = 1'b1;
                is_store  = 1'b1;
                alu_op    = 4'b0000;  // ADD for address calculation
            end

            // BRANCH instructions
            7'b1100011: begin
                branch  = 1'b1;
                alu_op  = 4'b0001;    // SUB for comparison
            end

            // JAL instructions
            7'b1101111: begin
                jump      = 1'b1;
                reg_write = 1'b1;
                wb_sel    = 2'b10;    // PC+4
                alu_op    = 4'b0000;  // ADD (not used but defined)
            end

            // JALR instructions
            7'b1100111: begin
                jr        = 1'b1;
                alu_src   = 1'b1;
                reg_write = 1'b1;
                wb_sel    = 2'b10;    // PC+4
                alu_op    = 4'b0000;  // ADD for address calculation
            end

            // LUI instruction
            7'b0110111: begin
                alu_src   = 1'b1;     // select immediate operand (critical fix)
                reg_write = 1'b1;
                alu_op    = 4'b0000;  // Pass through (result is immediate)
            end

            // AUIPC instruction
            7'b0010111: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
                alu_op    = 4'b0000;  // ADD: PC + immediate
            end

            // SYSTEM instructions (ECALL, EBREAK, etc.)
            7'b1110011: begin
                // ECALL / EBREAK are exception-generating instructions.
                // They are not decoded here; the CPU should detect them
                // externally and initiate a trap. All control signals
                // remain at default (safe) values.
                // No register write, no memory access, no ALU operation.
            end

            // Default case - all signals already at default values
            default: begin
                // All control signals remain at their default values
            end
        endcase
    end

endmodule