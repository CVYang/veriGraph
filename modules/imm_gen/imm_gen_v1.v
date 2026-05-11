module imm_gen (
    input      [31:0] instr,
    output reg [31:0] imm
);

    // Extract opcode bits[6:2] to determine immediate type
    wire [6:2] opcode;
    assign opcode = instr[6:2];

    // I-type: bits[31:20], sign-extended
    wire [31:0] i_imm;
    assign i_imm = {{20{instr[31]}}, instr[31:20]};

    // S-type: bits[31:25]||bits[11:7], sign-extended
    wire [31:0] s_imm;
    assign s_imm = {{20{instr[31]}}, instr[31:25], instr[11:7]};

    // B-type: bit[31]||bit[7]||bits[30:25]||bits[11:8]||0
    wire [31:0] b_imm;
    assign b_imm = {{20{instr[31]}}, instr[31], instr[7],
                    instr[30:25], instr[11:8], 1'b0};

    // U-type: bits[31:12]||12'h000
    wire [31:0] u_imm;
    assign u_imm = {instr[31:12], 12'b0};

    // J-type: bit[31]||bits[19:12]||bit[20]||bits[30:21]||0
    wire [31:0] j_imm;
    assign j_imm = {{20{instr[31]}}, instr[31], instr[19:12],
                    instr[20], instr[30:21], 1'b0};

    always @(*) begin
        case (opcode)
            5'b00000: imm = i_imm;   // Load (I-type immediate)
            5'b00100: imm = i_imm;   // I-type arithmetic
            5'b01100: imm = i_imm;   // OP-IMM (I-type)
            5'b01000: imm = s_imm;   // Store (S-type)
            5'b11000: imm = b_imm;   // Branch (B-type)
            5'b01101: imm = u_imm;   // LUI (U-type)
            5'b00101: imm = u_imm;   // AUIPC (U-type)
            5'b11011: imm = j_imm;   // JAL (J-type)
            default:  imm = 32'b0;
        endcase
    end

endmodule