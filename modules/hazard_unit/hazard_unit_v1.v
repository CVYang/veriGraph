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
    // Flush IF and ID when branch/jump is taken
    // PC was already updated to branch target, need to clear wrong-path instructions
    // ================================================================
    assign flush_if = (branch_taken || jump_taken);
    assign flush_id = (branch_taken || jump_taken);
    
    // EX stage flush - not typically needed since branch resolves in EX
    assign flush_ex = 1'b0;

    // ================================================================
    // Forwarding Logic
    // Priority: MEM > WB > Register File
    // Forward data to ALU inputs in EX stage
    // ================================================================
    always @(*) begin
        // Default forwarding selects (use register file values)
        fwd_alu_a = 2'b00;
        fwd_alu_b = 2'b00;
        
        // Forward MEM result (highest priority)
        if (mem_reg_write && (id_rs1_addr == mem_rd_addr) && (id_rs1_addr != 5'd0)) begin
            fwd_alu_a = 2'b01;  // Select MEM result for operand A
        end
        
        if (mem_reg_write && (id_rs2_addr == mem_rd_addr) && (id_rs2_addr != 5'd0)) begin
            fwd_alu_b = 2'b01;  // Select MEM result for operand B
        end
        
        // Forward WB result (lower priority than MEM)
        if (wb_reg_write && (id_rs1_addr == wb_rd_addr) && 
            (id_rs1_addr != 5'd0) && (fwd_alu_a == 2'b00)) begin
            fwd_alu_a = 2'b10;  // Select WB result for operand A
        end
        
        if (wb_reg_write && (id_rs2_addr == wb_rd_addr) && 
            (id_rs2_addr != 5'd0) && (fwd_alu_b == 2'b00)) begin
            fwd_alu_b = 2'b10;  // Select WB result for operand B
        end
        
        // Forward data values (combinational pass-through)
        fwd_mem_result = mem_result;
        fwd_wb_result  = wb_result;
    end

endmodule