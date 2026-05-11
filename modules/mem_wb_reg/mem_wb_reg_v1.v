module mem_wb_reg (
    input wire clk,
    input wire rst_n,
    input wire flush,
    input wire [31:0] mem_rdata,
    input wire [31:0] mem_alu_out,
    input wire [4:0] mem_rd_addr,
    input wire mem_reg_write,
    input wire [1:0] mem_wb_sel,
    input wire mem_valid,
    output reg [31:0] wb_mem_rdata,
    output reg [31:0] wb_alu_result,
    output reg [4:0] wb_rd_addr,
    output reg wb_reg_write,
    output reg [1:0] wb_wb_sel,
    output reg wb_valid
);

always @(posedge clk or negedge rst_n) begin
    if (!rst_n) begin
        wb_mem_rdata <= 32'h0;
        wb_alu_result <= 32'h0;
        wb_rd_addr <= 5'h0;
        wb_reg_write <= 1'b0;
        wb_wb_sel <= 2'b0;
        wb_valid <= 1'b0;
    end else if (flush) begin
        wb_mem_rdata <= 32'h0;
        wb_alu_result <= 32'h0;
        wb_rd_addr <= 5'h0;
        wb_reg_write <= 1'b0;
        wb_wb_sel <= 2'b0;
        wb_valid <= 1'b0;
    end else begin
        wb_mem_rdata <= mem_rdata;
        wb_alu_result <= mem_alu_out;
        wb_rd_addr <= mem_rd_addr;
        wb_reg_write <= mem_reg_write;
        wb_wb_sel <= mem_wb_sel;
        wb_valid <= mem_valid;
    end
end

endmodule