module mem_stage (
    input wire clk,
    input wire rst_n,
    input wire [31:0] mem_alu_result,
    input wire [31:0] mem_wdata,
    input wire [4:0] mem_rd_addr,
    input wire mem_read,
    input wire mem_write,
    input wire [2:0] mem_funct3,
    input wire mem_reg_write,
    input wire [1:0] mem_wb_sel,
    input wire mem_valid,
    output wire [31:0] dmem_addr,
    output wire [31:0] dmem_wdata,
    input wire [31:0] dmem_rdata,
    output wire dmem_req,
    output wire dmem_we,
    output wire [3:0] dmem_be,
    output reg [31:0] mem_rdata,
    output reg [31:0] mem_alu_out,
    output reg [4:0] mem_rd_addr_out,
    output reg mem_reg_write_out,
    output reg [1:0] mem_wb_sel_out,
    output reg mem_valid_out
);

    wire mem_req_active;
    wire mem_addr_bit1;
    wire [1:0] mem_addr_bits;

    assign mem_req_active = mem_read | mem_write;
    assign mem_addr_bit1 = mem_alu_result[1];
    assign mem_addr_bits = mem_alu_result[1:0];
    assign dmem_addr = mem_alu_result;
    assign dmem_wdata = mem_wdata;
    assign dmem_req = mem_req_active;
    assign dmem_we = mem_write;

    always @(*) begin
        case (mem_funct3)
            3'b000: begin  // LB or SB
                if (mem_read) begin
                    dmem_be = (mem_addr_bits == 2'b00) ? 4'b0001 :
                              (mem_addr_bits == 2'b01) ? 4'b0010 :
                              (mem_addr_bits == 2'b10) ? 4'b0100 : 4'b1000;
                end else if (mem_write) begin
                    dmem_be = (mem_addr_bits == 2'b00) ? 4'b0001 :
                              (mem_addr_bits == 2'b01) ? 4'b0010 :
                              (mem_addr_bits == 2'b10) ? 4'b0100 : 4'b1000;
                end else begin
                    dmem_be = 4'b0000;
                end
            end

            3'b001: begin  // LH or SH
                if (mem_read) begin
                    dmem_be = (mem_addr_bit1 == 1'b0) ? 4'b0011 : 4'b1100;
                end else if (mem_write) begin
                    dmem_be = (mem_addr_bit1 == 1'b0) ? 4'b0011 : 4'b1100;
                end else begin
                    dmem_be = 4'b0000;
                end
            end

            3'b010: begin  // LW or SW
                dmem_be = (mem_read | mem_write) ? 4'b1111 : 4'b0000;
            end

            3'b100: begin  // LBU
                if (mem_read) begin
                    dmem_be = (mem_addr_bits == 2'b00) ? 4'b0001 :
                              (mem_addr_bits == 2'b01) ? 4'b0010 :
                              (mem_addr_bits == 2'b10) ? 4'b0100 : 4'b1000;
                end else begin
                    dmem_be = 4'b0000;
                end
            end

            3'b101: begin  // LHU
                if (mem_read) begin
                    dmem_be = (mem_addr_bit1 == 1'b0) ? 4'b0011 : 4'b1100;
                end else begin
                    dmem_be = 4'b0000;
                end
            end

            default: begin
                dmem_be = 4'b0000;
            end
        endcase
    end

    always @(*) begin
        case (mem_funct3)
            3'b000: begin  // LB (load byte signed)
                case (mem_addr_bits)
                    2'b00: mem_rdata = {{24{dmem_rdata[7]}}, dmem_rdata[7:0]};
                    2'b01: mem_rdata = {{24{dmem_rdata[15]}}, dmem_rdata[15:8]};
                    2'b10: mem_rdata = {{24{dmem_rdata[23]}}, dmem_rdata[23:16]};
                    2'b11: mem_rdata = {{24{dmem_rdata[31]}}, dmem_rdata[31:24]};
                endcase
            end

            3'b001: begin  // LH (load half signed)
                case (mem_addr_bit1)
                    1'b0: mem_rdata = {{16{dmem_rdata[15]}}, dmem_rdata[15:0]};
                    1'b1: mem_rdata = {{16{dmem_rdata[31]}}, dmem_rdata[31:16]};
                endcase
            end

            3'b010: begin  // LW (load word)
                mem_rdata = dmem_rdata;
            end

            3'b100: begin  // LBU (load byte unsigned)
                case (mem_addr_bits)
                    2'b00: mem_rdata = {24'b0, dmem_rdata[7:0]};
                    2'b01: mem_rdata = {24'b0, dmem_rdata[15:8]};
                    2'b10: mem_rdata = {24'b0, dmem_rdata[23:16]};
                    2'b11: mem_rdata = {24'b0, dmem_rdata[31:24]};
                endcase
            end

            3'b101: begin  // LHU (load half unsigned)
                case (mem_addr_bit1)
                    1'b0: mem_rdata = {16'b0, dmem_rdata[15:0]};
                    1'b1: mem_rdata = {16'b0, dmem_rdata[31:16]};
                endcase
            end

            default: begin
                mem_rdata = 32'b0;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (~rst_n) begin
            mem_alu_out <= 32'b0;
            mem_rd_addr_out <= 5'b0;
            mem_reg_write_out <= 1'b0;
            mem_wb_sel_out <= 2'b0;
            mem_valid_out <= 1'b0;
        end else begin
            mem_alu_out <= mem_alu_result;
            mem_rd_addr_out <= mem_rd_addr;
            mem_reg_write_out <= mem_reg_write;
            mem_wb_sel_out <= mem_wb_sel;
            mem_valid_out <= mem_valid;
        end
    end

endmodule