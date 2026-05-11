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
assign id_imm      = gen_imm;
assign id_pc_out   = id_pc;

control_unit cu (
    .instr(id_instr),
    .alu_src(cu_alu_src),
    .alu_op(cu_alu_op),
    .mem_read(cu_mem_read),
    .mem_write(cu_mem_write),
    .reg_write(cu_reg_write),
    .wb_sel(cu_wb_sel),
    .branch(cu_branch),
    .jump(cu_jump),
    .jr(cu_jr),
    .funct3()
);

imm_gen ig (
    .instr(id_instr),
    .imm(gen_imm)
);

always @(*) begin
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

    if (flush) begin
        id_alu_src   = 1'b1;
    end else begin
        id_alu_src     = cu_alu_src;
        id_alu_op      = cu_alu_op;
        id_mem_read    = cu_mem_read;
        id_mem_write   = cu_mem_write;
        id_reg_write   = cu_reg_write;
        id_wb_sel      = cu_wb_sel;
        id_branch      = cu_branch;
        id_jump        = cu_jump;
        id_jr          = cu_jr;

        if (cu_jump) begin
            id_pc_redirect = 1'b1;
            id_pc_target   = id_pc + gen_imm;
        end else if (cu_jr) begin
            id_pc_redirect = 1'b1;
            id_pc_target   = {rf_rs1_data[31:12], gen_imm[11:0]};
        end
    end
end

endmodule