module if_stage (
    input wire         clk,
    input wire         rst_n,
    input wire         stall,
    input wire         flush,
    input wire         pc_redirect,
    input wire [31:0]  pc_target,
    output wire [31:0] imem_addr,
    input wire [31:0]  imem_rdata,
    output reg         imem_req,
    output reg [31:0]  if_pc,
    output reg [31:0]  if_instr,
    output reg         if_valid
);

    reg [31:0] pc;
    wire [31:0] pc_next;

    always @(*) begin
        if (!rst_n) begin
            pc_next = 32'h0;
        end else if (stall) begin
            pc_next = pc;
        end else if (pc_redirect) begin
            pc_next = pc_target;
        end else begin
            pc_next = pc + 32'h4;
        end
    end

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0;
        end else begin
            pc <= pc_next;
        end
    end

    assign imem_addr = pc;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_req <= 1'b0;
            if_pc   <= 32'h0;
            if_instr <= 32'h0;
            if_valid <= 1'b0;
        end else begin
            imem_req <= 1'b1;
            if_pc   <= pc;
            if_instr <= imem_rdata;
            if_valid <= !(stall || flush);
        end
    end

endmodule