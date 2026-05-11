module alu (
    input wire [31:0] a,
    input wire [31:0] b,
    input wire [3:0] op,
    output reg [31:0] result,
    output wire zero
);

    wire signed [31:0] a_signed;
    wire signed [31:0] b_signed;
    wire [4:0] shamt;

    assign a_signed = a;
    assign b_signed = b;
    assign shamt = b[4:0];

    always @(*) begin
        case (op)
            4'd0:  result = a + b;
            4'd1:  result = a - b;
            4'd2:  result = a << shamt;
            4'd3:  result = (a_signed < b_signed) ? 32'd1 : 32'd0;
            4'd4:  result = (a < b) ? 32'd1 : 32'd0;
            4'd5:  result = a ^ b;
            4'd6:  result = a >> shamt;
            4'd7:  result = a_signed >>> shamt;
            4'd8:  result = a | b;
            4'd9:  result = a & b;
            default: result = 32'd0;
        endcase
    end

    assign zero = (result == 32'd0);

endmodule