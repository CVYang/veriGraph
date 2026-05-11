module id_stage (
    input  logic       clk,
    input  logic       rst_n,
    input  logic [31:0] id_pc,
    input  logic [31:0] id_instr,
    input  logic       id_valid,
    input  logic       flush,
    output logic [4:0]  rf_rs1_addr,
    output logic [4:0]  rf_rs2_addr,
    input  logic [31:0] rf_rs1_data,
    input  logic [31:0] rf_rs2_data,
    output logic [4:0]  id_rs1_addr,
    output logic [4:0]  id_rs2_addr,
    output logic [31:0] id_rs1_data,
    output logic [31:0] id_rs2_data,
    output logic [31:0] id_imm,
    output logic [4:0]  id_rd_addr,
    output logic [31:0] id_pc_out,
    output logic        id_alu_src,
    output logic [3:0]  id_alu_op,
    output logic        id_mem_read,
    output logic        id_mem_write,
    output logic [2:0]  id_funct3,
    output logic        id_reg_write,
    output logic [1:0]  id_wb_sel,
    output logic        id_branch,
    output logic        id_jump,
    output logic        id_jr,
    output logic        id_pc_redirect,
    output logic [31:0] id_pc_target
);

    wire [6:0] opcode;
    wire [2:0] funct3;
    wire [6:0] funct7;
    wire [4:0] rs1_addr;
    wire [4:0] rs2_addr;
    wire [4:0] rd_addr;

    wire        cu_alu_src;
    wire [3:0]  cu_alu_op;
    wire        cu_mem_read;
    wire        cu_mem_write;
    wire        cu_reg_write;
    wire [1:0]  cu_wb_sel;
    wire        cu_branch;
    wire        cu_jump;
    wire        cu_jr;
    wire [31:0] gen_imm;

    // Pipeline register for pc_target to break combinational path from rf_rs1_data
    logic       pc_redirect_reg;
    logic [31:0] pc_target_reg;
    logic       pc_redirect_next;
    logic [31:0] pc_target_next;

    assign opcode   = id_instr[6:0];
    assign funct3   = id_instr[14:12];
    assign funct7   = id_instr[31:25];
    assign rs1_addr = id_instr[19:15];
    assign rs2_addr = id_instr[24:20];
    assign rd_addr  = id_instr[11:7];

    assign rf_rs1_addr = rs1_addr;
    assign rf_rs2_addr = rs2_addr;

    assign id_rs1_addr = rs1_addr;
    assign id_rs2_addr = rs2_addr;
    assign id_rs1_data = rf_rs1_data;
    assign id_rs2_data = rf_rs2_data;
    assign id_rd_addr  = rd_addr;
    assign id_funct3   = funct3;

    // JALR target uses lower 12 bits of gen_imm as offset
    // gen_imm is I-type immediate sign-extended to 32 bits
    assign id_imm = gen_imm;

    control_unit cu (
        .instr(id_instr),
        .funct3(funct3),  // FIX: Connect funct3 to control_unit
        .alu_src(cu_alu_src),
        .alu_op(cu_alu_op),
        .mem_read(cu_mem_read),
        .mem_write(cu_mem_write),
        .reg_write(cu_reg_write),
        .wb_sel(cu_wb_sel),
        .branch(cu_branch),
        .jump(cu_jump),
        .jr(cu_jr)
    );

    imm_gen ig (
        .instr(id_instr),
        .imm(gen_imm)
    );

    // Compute next values for pc_target register
    always @(*) begin
        if (flush) begin
            pc_redirect_next = 1'b0;
            pc_target_next   = 32'b0;
        end else begin
            pc_redirect_next = 1'b0;
            pc_target_next   = 32'b0;

            if (cu_jump) begin
                pc_redirect_next = 1'b1;
                pc_target_next   = id_pc + gen_imm;
            end else if (cu_jr) begin
                // JALR: target = rs1 + I-type immediate (sign-extended)
                // Lower 12 bits of gen_imm replace lower 12 bits of rs1 value
                pc_redirect_next = 1'b1;
                pc_target_next   = {rf_rs1_data[31:12], gen_imm[11:0]};
            end
        end
    end

    // Register pc_target to break long combinational path
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_redirect_reg <= 1'b0;
            pc_target_reg   <= 32'b0;
        end else begin
            pc_redirect_reg <= pc_redirect_next;
            pc_target_reg   <= pc_target_next;
        end
    end

    // FIX [high]: Set all control signals to safe disabled values (0) during flush
    // FIX [low]: Gate control signal generation with id_valid
    always @(*) begin
        // Default values: all disabled for safety
        id_alu_src     = 1'b0;
        id_alu_op      = 4'b0;
        id_mem_read    = 1'b0;
        id_mem_write   = 1'b0;
        id_reg_write   = 1'b0;
        id_wb_sel      = 2'b00;
        id_branch      = 1'b0;
        id_jump        = 1'b0;
        id_jr          = 1'b0;
        id_pc_redirect = 1'b0;
        id_pc_target   = 32'b0;
        id_pc_out      = id_pc;

        if (flush) begin
            // FIX: Set all control signals to 0 during flush to properly disable pipeline
            id_alu_src     = 1'b0;
            id_alu_op      = 4'b0;
            id_mem_read    = 1'b0;
            id_mem_write   = 1'b0;
            id_reg_write   = 1'b0;
            id_wb_sel      = 2'b00;
            id_branch      = 1'b0;
            id_jump        = 1'b0;
            id_jr          = 1'b0;
            id_pc_redirect = 1'b0;
            id_pc_target   = 32'b0;
        end else if (id_valid) begin
            // Only generate control signals when instruction is valid
            id_alu_src     = cu_alu_src;
            id_alu_op      = cu_alu_op;
            id_mem_read    = cu_mem_read;
            id_mem_write   = cu_mem_write;
            id_reg_write   = cu_reg_write;
            id_wb_sel      = cu_wb_sel;
            id_branch      = cu_branch;
            id_jump        = cu_jump;
            id_jr          = cu_jr;
            id_pc_redirect = pc_redirect_reg;
            id_pc_target   = pc_target_reg;
        end
    end

endmodule