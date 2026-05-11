module ex_mem_reg (
    input  logic        clk,
    input  logic        rst_n,
    input  logic        flush,
    input  logic [31:0] ex_alu_result,
    input  logic [31:0] ex_mem_wdata,
    input  logic [4:0]  ex_rd_addr,
    input  logic        ex_mem_read,
    input  logic        ex_mem_write,
    input  logic [2:0]  ex_funct3,
    input  logic        ex_reg_write,
    input  logic [1:0]  ex_wb_sel,
    input  logic        ex_valid,
    output logic [31:0] mem_alu_result,
    output logic [31:0] mem_wdata,
    output logic [4:0]  mem_rd_addr,
    output logic        mem_read,
    output logic        mem_write,
    output logic [2:0]  mem_funct3,
    output logic        mem_reg_write,
    output logic [1:0]  mem_wb_sel,
    output logic        mem_valid
);

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            mem_alu_result <= 32'h0;
            mem_wdata      <= 32'h0;
            mem_rd_addr    <= 5'h0;
            mem_read       <= 1'b0;
            mem_write      <= 1'b0;
            mem_funct3     <= 3'h0;
            mem_reg_write  <= 1'b0;
            mem_wb_sel     <= 2'h0;
            mem_valid      <= 1'b0;
        end else if (flush) begin
            mem_alu_result <= 32'h0;
            mem_wdata      <= 32'h0;
            mem_rd_addr    <= 5'h0;
            mem_read       <= 1'b0;
            mem_write      <= 1'b0;
            mem_funct3     <= 3'h0;
            mem_reg_write  <= 1'b0;
            mem_wb_sel     <= 2'h0;
            mem_valid      <= 1'b0;
        end else begin
            mem_alu_result <= ex_alu_result;
            mem_wdata      <= ex_mem_wdata;
            mem_rd_addr    <= ex_rd_addr;
            mem_read       <= ex_mem_read;
            mem_write      <= ex_mem_write;
            mem_funct3     <= ex_funct3;
            mem_reg_write  <= ex_reg_write;
            mem_wb_sel     <= ex_wb_sel;
            mem_valid      <= ex_valid;
        end
    end

endmodule