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

    // PC next logic: redirect has highest priority (over stall)
    // If reset active, PC = 0; else redirect to target; else stall holds PC; else increment.
    assign pc_next = (!rst_n)       ? 32'h0 :
                     pc_redirect    ? pc_target :
                     stall          ? pc :
                     (pc + 32'h4);

    // PC register
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc <= 32'h0;
        end else begin
            pc <= pc_next;
        end
    end

    // Instruction memory address driven by current PC
    assign imem_addr = pc;

    // Output registers with stall‑based enable
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_req <= 1'b0;
            if_pc   <= 32'h0;
            if_instr <= 32'h0;
            if_valid <= 1'b0;
        end else begin
            // imem_req is asserted continuously after reset
            imem_req <= 1'b1;

            // Only update instruction information on non‑stall cycles.
            // During stall, if_pc, if_instr, and if_valid hold their previous values.
            if (!stall) begin
                if_pc   <= pc;
                if_instr <= imem_rdata;
                if_valid <= !flush;
            end
        end
    end

endmodule