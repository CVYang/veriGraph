module wb_stage (
    input wire clk,
    input wire rst_n,
    input wire [31:0] wb_mem_rdata,
    input wire [31:0] wb_alu_result,
    input wire [4:0] wb_rd_addr,
    input wire wb_reg_write,
    input wire [1:0] wb_wb_sel,
    input wire wb_valid,
    output reg [4:0] rf_waddr,
    output reg [31:0] rf_wdata,
    output reg rf_we,
    output reg [31:0] wb_result
);

reg [31:0] selected_data;

always @(*) begin
    if (!wb_valid || wb_rd_addr == 5'd0) begin
        rf_waddr = 5'd0;
        rf_wdata = 32'd0;
        rf_we = 1'b0;
        wb_result = 32'd0;
        selected_data = 32'd0;
    end else begin
        rf_waddr = wb_rd_addr;
        rf_we = wb_reg_write;
        
        case (wb_wb_sel)
            2'b00: selected_data = wb_alu_result;
            2'b01: selected_data = wb_mem_rdata;
            2'b10: selected_data = wb_alu_result;
            default: selected_data = 32'd0;
        endcase
        
        rf_wdata = selected_data;
        wb_result = selected_data;
    end
end

reg_file u_reg_file (
    .clk(clk),
    .rst_n(rst_n),
    .rs1_addr(5'd0),
    .rs2_addr(5'd0),
    .rs1_data(),
    .rs2_data(),
    .waddr(rf_waddr),
    .wdata(rf_wdata),
    .we(rf_we)
);

endmodule