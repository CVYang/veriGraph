module id_ex_reg (
  input clk,
  input rst_n,
  input flush,
  input [4:0] id_rs1_addr,
  input [4:0] id_rs2_addr,
  input [31:0] id_rs1_data,
  input [31:0] id_rs2_data,
  input [31:0] id_imm,
  input [4:0] id_rd_addr,
  input [31:0] id_pc,
  input id_alu_src,
  input [3:0] id_alu_op,
  input id_mem_read,
  input id_mem_write,
  input [2:0] id_funct3,
  input id_reg_write,
  input [1:0] id_wb_sel,
  input id_branch,
  input id_jump,
  input id_jr,
  input id_valid,
  output reg [4:0] ex_rs1_addr,
  output reg [4:0] ex_rs2_addr,
  output reg [31:0] ex_rs1_data,
  output reg [31:0] ex_rs2_data,
  output reg [31:0] ex_imm,
  output reg [4:0] ex_rd_addr,
  output reg [31:0] ex_pc,
  output reg ex_alu_src,
  output reg [3:0] ex_alu_op,
  output reg ex_mem_read,
  output reg ex_mem_write,
  output reg [2:0] ex_funct3,
  output reg ex_reg_write,
  output reg [1:0] ex_wb_sel,
  output reg ex_branch,
  output reg ex_jump,
  output reg ex_jr,
  output reg ex_valid
);

  always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
      ex_rs1_addr   <= 5'b0;
      ex_rs2_addr   <= 5'b0;
      ex_rs1_data   <= 32'b0;
      ex_rs2_data   <= 32'b0;
      ex_imm        <= 32'b0;
      ex_rd_addr    <= 5'b0;
      ex_pc         <= 32'b0;
      ex_alu_src    <= 1'b0;
      ex_alu_op     <= 4'b0;
      ex_mem_read   <= 1'b0;
      ex_mem_write  <= 1'b0;
      ex_funct3     <= 3'b0;
      ex_reg_write  <= 1'b0;
      ex_wb_sel     <= 2'b0;
      ex_branch     <= 1'b0;
      ex_jump       <= 1'b0;
      ex_jr         <= 1'b0;
      ex_valid      <= 1'b0;
    end else if (flush) begin
      ex_valid      <= 1'b0;
    end else begin
      ex_rs1_addr   <= id_rs1_addr;
      ex_rs2_addr   <= id_rs2_addr;
      ex_rs1_data   <= id_rs1_data;
      ex_rs2_data   <= id_rs2_data;
      ex_imm        <= id_imm;
      ex_rd_addr    <= id_rd_addr;
      ex_pc         <= id_pc;
      ex_alu_src    <= id_alu_src;
      ex_alu_op     <= id_alu_op;
      ex_mem_read   <= id_mem_read;
      ex_mem_write  <= id_mem_write;
      ex_funct3     <= id_funct3;
      ex_reg_write  <= id_reg_write;
      ex_wb_sel     <= id_wb_sel;
      ex_branch     <= id_branch;
      ex_jump       <= id_jump;
      ex_jr         <= id_jr;
      ex_valid      <= id_valid;
    end
  end

endmodule