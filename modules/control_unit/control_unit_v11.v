module control_unit (
    input  wire [31:0] instr,       // 32-bit instruction
    output reg         alu_src,     // ALU source select (0=rs2, 1=imm)
    output reg  [3:0]  alu_op,      // ALU operation code
    output reg         mem_read,    // Memory read enable
    output reg         mem_write,   // Memory write enable
    output reg         reg_write,   // Register write enable
    output reg  [1:0]  wb_sel,      // Write-back select (00=ALU, 01=MEM, 10=PC+4)
    output reg         branch,      // Branch instruction flag
    output reg         jump,        // JAL instruction flag
    output reg         jr,          // JALR instruction flag
    output reg         is_load,     // Is load instruction flag
    output reg         is_store,    // Is store instruction flag
    output wire [2:0]  funct3       // funct3 field passthrough
);

    // Internal wires for instruction fields
    wire [6:0] opcode;
    wire [6:0] funct7;
    wire [2:0] funct3_internal;

    // Extract instruction fields
    assign opcode          = instr[6:0];
    assign funct7          = instr[31:25];
    assign funct3_internal = instr[14:12];
    assign funct3          = funct3_internal;

    // Main decoder - combinational logic
    always @(*) begin
        // Default values to avoid latch inference
        alu_src   = 1'b0;
        alu_op    = 4'b0000;
        mem_read  = 1'b0;
        mem_write = 1'b0;
        reg_write = 1'b0;
        wb_sel    = 2'b00;
        branch    = 1'b0;
        jump      = 1'b0;
        jr        = 1'b0;
        is_load   = 1'b0;
        is_store  = 1'b0;

        case (opcode[6:2])
            // LOAD (I-type): opcode[6:2] = 00000
            5'b00000: begin
                alu_src   = 1'b1;
                alu_op    = 4'b0000;  // ADD (base + offset)
                mem_read  = 1'b1;
                reg_write = 1'b1;
                wb_sel    = 2'b01;   // Write from memory
                is_load   = 1'b1;
            end

            // STORE (S-type): opcode[6:2] = 01000
            5'b01000: begin
                alu_src   = 1'b1;
                alu_op    = 4'b0o00;  // ADD (base + offset)
                mem_write = 1'b1;
                is_store  = 1'b1;
            end

            // BRANCH (B-type): opcode[6:2] = 11000
            5'b11000: begin
                alu_src   = 1'b0;
                alu_op    = 4'b0001;  // SUB for comparison
                branch    = 1'b1;
            end

            // JAL (J-type): opcode[6:2] = 11011
            5'b11011: begin
                reg_write = 1'b1;
                wb_sel    = 2'b10;   // Write PC+4
                jump      = 1'b1;
            end

            // JALR (I-type): opcode[6:2] = 11001
            5'b11001: begin
                alu_src   = 1'b1;
                alu_op    = 4'b0000;  // ADD
                reg_write = 1'b1;
                wb_sel    = 2'b10;    // Write PC+4
                jr        = 1'b1;
            end

            // OP-IMM (I-type): opcode[6:2] = 00100
            5'b00100: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
                case (funct3_internal)
                    3'b000: alu_op = 4'b0000;  // ADDI
                    3'b010: alu_op = 4'b0010;  // SLTI
                    3'b011: alu_op = 4'b0011;  // SLTIU
                    3'b100: alu_op = 4'b0100;  // XORI
                    3'b110: alu_op = 4'b0101;  // ORI
                    3'b111: alu_op = 4'b0110;  // ANDI
                    3'b001: alu_op = 4'b0111;  // SLLI
                    3'b101: begin
                        if (funct7[5]) begin
                            alu_op = 4'b1001;  // SRAI
                        end else begin
                            alu_op = 4'b1000;  // SRLI
                        end
                    end
                    default: alu_op = 4'b0000;
                endcase
            end

            // OP (R-type): opcode[6:2] = 01100
            5'b01100: begin
                alu_src   = 1'b0;
                reg_write = 1'b1;
                case (funct3_internal)
                    3'b000: begin
                        if (funct7[5]) begin
                            alu_op = 4'b0001;  // SUB
                        end else begin
                            alu_op = 4'b0000;  // ADD
                        end
                    end
                    3'b001: alu_op = 4'b0111;  // SLL
                    3'b010: alu_op = 4'b0010;  // SLT
                    3'b011: alu_op = 4'b0011;  // SLTU
                    3'b100: alu_op = 4'b0100;  // XOR
                    3'b101: begin
                        if (funct7[5]) begin
                            alu_op = 4'b1010;  // SRA
                        end else begin
                            alu_op = 4'b1000;  // SRL
                        end
                    end
                    3'b110: alu_op = 4'b0101;  // OR
                    3'b111: alu_op = 4'b0110;  // AND
                    default: alu_op = 4'b0000;
                endcase
            end

            // LUI (U-type): opcode[6:2] = 01101
            5'b01101: begin
                alu_src   = 1'b1;
                alu_op    = 4'b1100;  // LUI (pass imm directly)
                reg_write = 1'b1;
            end

            // AUIPC (U-type): opcode[6:2] = 00101
            5'b00101: begin
                alu_src   = 1'b1;
                alu_op    = 4'b1101;  // AUIPC (PC + imm)
                reg_write = 1'b1;
            end

            // OP-IMM-32 (I-type): opcode[6:2] = 00110
            5'b00110: begin
                alu_src   = 1'b1;
                reg_write = 1'b1;
                case (funct3_internal)
                    3'b000: begin
                        if (funct7[5]) begin
                            alu_op = 4'b1011;  // SUBW
                        end else begin
                            alu_op = 4'b1010;  // ADDW
                        end
                    end
                    3'b001: alu_op = 4'b1110;  // SLLIW
                    3'b101: begin
                        if (funct7[5]) begin
                            alu_op = 4'b1111;  // SRAIW
                        end else begin
                            alu_op = 4'b1010;  // Reserved / SRLIW
                        end
                    end
                    default: alu_op = 4'b0000;
                endcase
            end

            // OP-32 (R-type): opcode[6:2] = 01110
            5'b01110: begin
                alu_src   = 1'b0;
                reg_write = 1'b1;
                case (funct3_internal)
                    3'b000: begin
                        if (funct7[5]) begin
                            alu_op = 4'b1011;  // SUBW
                        end else begin
                            alu_op = 4'b1010;  // ADDW
                        end
                    end
                    3'b001: alu_op = 4'b1110;  // SLLW
                    3'b101: begin
                        if (funct7[5]) begin
                            alu_op = 4'b1111;  // SRAW
                        end else begin
                            alu_op = 4'b1010;  // Reserved / SRLW
                        end
                    end
                    default: alu_op = 4'b0000;
                endcase
            end

            // Default case - NOP/invalid
            default: begin
                alu_src   = 1'b0;
                alu_op    = 4'b0000;
                mem_read  = 1'b0;
                mem_write = 1'b0;
                reg_write = 1'b0;
                wb_sel    = 2'b00;
                branch    = 1'b0;
                jump      = 1'b0;
                jr        = 1'b0;
                is_load   = 1'b0;
                is_store  = 1'b0;
            end
        endcase
    end

endmodule