module hazard_unit (
    // Clock and Reset
    input  logic        clk,
    input  logic        rst_n,
    
    // ID Stage
    input  logic [4:0]  id_rs1_addr,
    input  logic [4:0]  id_rs2_addr,
    input  logic        id_branch,
    input  logic        id_jump,
    input  logic        id_jr,
    
    // EX Stage
    input  logic [4:0]  ex_rd_addr,
    input  logic        ex_mem_read,
    input  logic        ex_reg_write,
    input  logic [31:0] ex_result,      // Added for EX forwarding
    
    // MEM Stage
    input  logic [4:0]  mem_rd_addr,
    input  logic        mem_reg_write,
    input  logic [31:0] mem_result,
    
    // WB Stage
    input  logic [4:0]  wb_rd_addr,
    input  logic        wb_reg_write,
    input  logic [31:0] wb_result,
    
    // Control Signals
    input  logic        branch_taken,
    input  logic        jump_taken,
    
    // Stall/Flush Outputs
    output logic        stall_if,
    output logic        stall_id,
    output logic        flush_if,
    output logic        flush_id,
    output logic        flush_ex,
    
    // Forwarding Outputs
    output logic [1:0]  fwd_alu_a,
    output logic [1:0]  fwd_alu_b,
    output logic [31:0] fwd_ex_result,  // Added for EX forwarding data
    output logic [31:0] fwd_mem_result,
    output logic [31:0] fwd_wb_result
);

    // ================================================================
    // Load-Use Hazard Detection
    // Stall when: EX has a load instruction, destination register is non-zero,
    // and ID stage instruction needs the loaded value
    // ================================================================
    wire load_use_hazard;
    assign load_use_hazard = ex_mem_read && 
                             ex_reg_write && 
                             (ex_rd_addr != 5'd0) &&
                             ((id_rs1_addr == ex_rd_addr) || 
                              (id_rs2_addr == ex_rd_addr));

    // PC write enable (IF stage stall) - freeze PC during load-use
    assign stall_if = load_use_hazard;
    
    // ID stage stall - hold current instruction in ID
    assign stall_id = load_use_hazard;

    // ================================================================
    // Control Hazard Handling
    // Flush IF and ID appropriately for branches and jumps
    // ================================================================
    // flush_if: discard instruction fetched after a taken branch or jump
    assign flush_if = (branch_taken || jump_taken);
    
    // flush_id: discard wrong-path instruction after a taken branch.
    // Branch resolves in EX, so the instruction in ID that followed it is wrong.
    // For a jump (resolved in ID), the jump itself is in ID and must NOT be flushed.
    assign flush_id = branch_taken;
    
    // EX stage is never flushed because:
    // - Branches resolve in EX but the branch itself remains valid.
    // - Jumps are handled in ID and never enter EX.
    // No other control hazard scenarios require an EX flush in this design.
    assign flush_ex = 1'b0;

    // ================================================================
    // Forwarding Logic
    // Priority: EX > MEM > WB > Register File
    // EX forwarding is added to handle dependencies where the producing
    // instruction is still in the EX stage (result available early).
    // ================================================================
    // Data pass-through for forwarding multiplexers
    assign fwd_ex_result = ex_result;
    assign fwd_mem_result = mem_result;
    assign fwd_wb_result  = wb_result;

    always @(*) begin
        if (stall_id) begin
            // ID stage is frozen; EX stage executes a bubble.
            // No forwarding needed, avoid unnecessary toggling.
            fwd_alu_a = 2'b00;
            fwd_alu_b = 2'b00;
        end else begin
            // Default: use register file values
            fwd_alu_a = 2'b00;
            fwd_alu_b = 2'b00;
            
            // ---------- EX forwarding (highest priority) ----------
            if (ex_reg_write && (ex_rd_addr != 5'd0) && (id_rs1_addr == ex_rd_addr)) begin
                fwd_alu_a = 2'b11;  // Forward EX result for operand A
            end
            if (ex_reg_write && (ex_rd_addr != 5'd0) && (id_rs2_addr == ex_rd_addr)) begin
                fwd_alu_b = 2'b11;  // Forward EX result for operand B
            end
            
            // ---------- MEM forwarding (second priority) ----------
            if (mem_reg_write && (mem_rd_addr != 5'd0) && (id_rs1_addr == mem_rd_addr) && (fwd_alu_a == 2'b00)) begin
                fwd_alu_a = 2'b01;  // Select MEM result for operand A
            end
            if (mem_reg_write && (mem_rd_addr != 5'd0) && (id_rs2_addr == mem_rd_addr) && (fwd_alu_b == 2'b00)) begin
                fwd_alu_b = 2'b01;  // Select MEM result for operand B
            end
            
            // ---------- WB forwarding (lowest priority) ----------
            if (wb_reg_write && (wb_rd_addr != 5'd0) && (id_rs1_addr == wb_rd_addr) && (fwd_alu_a == 2'b00)) begin
                fwd_alu_a = 2'b10;  // Select WB result for operand A
            end
            if (wb_reg_write && (wb_rd_addr != 5'd0) && (id_rs2_addr == wb_rd_addr) && (fwd_alu_b == 2'b00)) begin
                fwd_alu_b = 2'b10;  // Select WB result for operand B
            end
        end
    end

endmodule