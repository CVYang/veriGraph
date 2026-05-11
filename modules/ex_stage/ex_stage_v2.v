module ex_stage (
    input wire [31:0] ex_pc,
    input wire [31:0] ex_rs1_data,
    input wire [31:0] ex_rs2_data,
    input wire [31:0] ex_imm,
    input wire [4:0] ex_rd_addr,
    input wire ex_alu_src,
    input wire [3:0] ex_alu_op,
    input wire ex_mem_read,
    input wire ex_mem_write,
    input wire [2:0] ex_funct3,
    input wire ex_reg_write,
    input wire [1:0] ex_wb_sel,
    input wire ex_branch,
    input wire ex_jump,
    input wire ex_jr,
    input wire ex_valid,
    input wire flush,
    input wire [1:0] fwd_alu_a,
    input wire [1:0] fwd_alu_b,
    input wire [31:0] fwd_mem_result,
    input wire [31:0] fwd_wb_result,
    output reg [31:0] alu_a,
    output reg [31:0] alu_b,
    output wire [3:0] alu_op,
    input wire [31:0] alu_result,
    input wire alu_zero,
    output reg branch_taken,
    output reg [31:0] branch_target,
    output reg [31:0] ex_alu_result,
    output reg [31:0] ex_mem_wdata,
    output reg [4:0] ex_rd_addr_out,
    output reg ex_mem_read_out,
    output reg ex_mem_write_out,
    output reg [2:0] ex_funct3_out,
    output reg ex_reg_write_out,
    output reg [1:0] ex_wb_sel_out,
    output reg ex_valid_out
);

    // ---------------------------------------------------------
    // ALU operand A forwarding mux
    // ---------------------------------------------------------
    always @(*) begin
        case (fwd_alu_a)
            2'b00: alu_a = ex_rs1_data;
            2'b01: alu_a = fwd_mem_result;
            2'b10: alu_a = fwd_wb_result;
            default: alu_a = 32'h0;
        endcase
    end

    // ---------------------------------------------------------
    // ALU operand B forwarding mux (raw rs2 before ALU src mux)
    // ---------------------------------------------------------
    reg [31:0] alu_b_raw;
    always @(*) begin
        case (fwd_alu_b)
            2'b00: alu_b_raw = ex_rs2_data;
            2'b01: alu_b_raw = fwd_mem_result;
            2'b10: alu_b_raw = fwd_wb_result;
            default: alu_b_raw = 32'h0;
        endcase
    end

    // ---------------------------------------------------------
    // ALU operand B final selection (immediate or forwarded rs2)
    // ---------------------------------------------------------
    always @(*) begin
        alu_b = ex_alu_src ? ex_imm : alu_b_raw;
    end

    // ---------------------------------------------------------
    // ALU operation code pass-through
    // ---------------------------------------------------------
    assign alu_op = ex_alu_op;

    // ---------------------------------------------------------
    // Branch condition decode
    // ---------------------------------------------------------
    wire is_beq  = (ex_funct3 == 3'b000);
    wire is_bne  = (ex_funct3 == 3'b001);
    wire is_blt  = (ex_funct3 == 3'b100);
    wire is_bge  = (ex_funct3 == 3'b101);
    wire is_bltu = (ex_funct3 == 3'b110);
    wire is_bgeu = (ex_funct3 == 3'b111);

    // ---------------------------------------------------------
    // Branch resolution logic (using comparators to avoid ALU overflow issues)
    // ---------------------------------------------------------
    reg take_branch;
    always @(*) begin
        if (ex_branch) begin
            if (is_beq)      take_branch = alu_zero;
            else if (is_bne) take_branch = ~alu_zero;
            else if (is_blt) take_branch = ($signed(alu_a) < $signed(alu_b));
            else if (is_bge) take_branch = ($signed(alu_a) >= $signed(alu_b));
            else if (is_bltu) take_branch = (alu_a < alu_b);
            else if (is_bgeu) take_branch = (alu_a >= alu_b);
            else              take_branch = 1'b0;
        end else begin
            take_branch = 1'b0;
        end
    end

    // ---------------------------------------------------------
    // Branch / jump target calculation
    // ---------------------------------------------------------
    wire [31:0] pc_plus_imm;
    assign pc_plus_imm = ex_pc + ex_imm;

    // ---------------------------------------------------------
    // EX/MEM pipeline outputs and branch/jump control
    // ---------------------------------------------------------
    always @(*) begin
        if (flush) begin
            ex_alu_result    = alu_result;
            ex_mem_wdata     = alu_b_raw;          // Store data forwarded
            ex_rd_addr_out   = ex_rd_addr;
            ex_mem_read_out  = 1'b0;
            ex_mem_write_out = 1'b0;
            ex_funct3_out    = ex_funct3;
            ex_reg_write_out = 1'b0;
            ex_wb_sel_out    = ex_wb_sel;
            ex_valid_out     = 1'b0;
            branch_taken     = 1'b0;
            branch_target    = 32'h0;
        end else begin
            ex_alu_result    = alu_result;
            ex_mem_wdata     = alu_b_raw;          // Store data forwarded
            ex_rd_addr_out   = ex_rd_addr;
            ex_mem_read_out  = ex_mem_read;
            ex_mem_write_out = ex_mem_write;
            ex_funct3_out    = ex_funct3;
            ex_reg_write_out = ex_reg_write;
            ex_wb_sel_out    = ex_wb_sel;
            ex_valid_out     = ex_valid;

            // Jump and branch target resolution
            if (ex_jump) begin                     // JAL
                branch_target = pc_plus_imm;
                branch_taken  = 1'b1;
            end else if (ex_jr) begin              // JALR
                branch_target = alu_result;
                branch_taken  = 1'b1;
            end else if (ex_branch) begin          // Conditional branch
                branch_target = pc_plus_imm;
                branch_taken  = take_branch;
            end else begin
                branch_target = 32'h0;
                branch_taken  = 1'b0;
            end
        end
    end

endmodule