module if_id_reg (
    input wire clk,
    input wire rst_n,
    input wire flush,
    input wire stall,
    input wire [31:0] if_pc,
    input wire [31:0] if_instr,
    input wire if_valid,
    output reg [31:0] id_pc,
    output reg [31:0] id_instr,
    output reg id_valid
);

always @(posedge clk) begin
    if (!rst_n) begin
        id_pc <= 32'h0;
        id_instr <= 32'h0;
        id_valid <= 1'b0;
    end else if (flush) begin
        id_pc <= 32'h0;
        id_instr <= 32'h0;
        id_valid <= 1'b0;
    end else if (stall) begin
        id_pc <= id_pc;
        id_instr <= id_instr;
        id_valid <= id_valid;
    end else begin
        id_pc <= if_pc;
        id_instr <= if_instr;
        id_valid <= if_valid;
    end
end

endmodule