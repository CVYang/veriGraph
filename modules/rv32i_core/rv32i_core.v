// ============================================================================
// rv32i_core - Top-level wrapper for the RV32I 5-stage pipeline core
// Instantiates all submodules and connects them according to the datapath.
// ============================================================================

module rv32i_core (
    input  logic        clk,
    input  logic        rst_n,

    // Instruction memory interface
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,
    output logic        imem_req,

    // Data memory interface
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    input  logic [31:0] dmem_rdata,
    output logic        dmem_req,
    output logic        dmem_we,
    output logic [3:0]  dmem_be
);

    // ========================================================================
    // Internal wires for pipeline connectivity
    // ========================================================================

    // IF stage outputs
    logic [31:0] if_pc;
    logic [31:0] if_instr;
    logic        if_valid;

    // IF/ID register outputs
    logic [31:0] id_pc;
    logic [31:0] id_instr;
    logic        id_valid;

    // ID stage outputs
    logic [4:0]  rf_rs1_addr;
    logic [4:0]  rf_rs2_addr;
    logic [31:0] rf_rs1_data;
    logic [31:0] rf_rs2_data;
    logic [4:0]  id_rs1_addr;
    logic [4:0]  id_rs2_addr;
    logic [31:0] id_rs1_data;
    logic [31:0] id_rs2_data;
    logic [31:0] id_imm;
    logic [4:0]  id_rd_addr;
    logic [31:0] id_pc_out;
    logic        id_alu_src;
    logic [3:0]  id_alu_op;
    logic        id_mem_read;
    logic        id_mem_write;
    logic [2:0]  id_funct3;
    logic        id_reg_write;
    logic [1:0]  id_wb_sel;
    logic        id_branch;
    logic        id_jump;
    logic        id_jr;
    logic        id_pc_redirect;
    logic [31:0] id_pc_target;

    // ID/EX register outputs
    logic [4:0]  ex_rs1_addr;
    logic [4:0]  ex_rs2_addr;
    logic [31:0] ex_rs1_data;
    logic [31:0] ex_rs2_data;
    logic [31:0] ex_imm;
    logic [4:0]  ex_rd_addr;
    logic [31:0] ex_pc;
    logic        ex_alu_src;
    logic [3:0]  ex_alu_op;
    logic        ex_mem_read;
    logic        ex_mem_write;
    logic [2:0]  ex_funct3;
    logic        ex_reg_write;
    logic [1:0]  ex_wb_sel;
    logic        ex_branch;
    logic        ex_jump;
    logic        ex_jr;
    logic        ex_valid;

    // EX stage outputs (named to avoid conflicts)
    logic [31:0] alu_a;
    logic [31:0] alu_b;
    logic [3:0]  alu_op;
    logic [31:0] alu_result;
    logic        alu_zero;
    logic        branch_taken;
    logic [31:0] branch_target;

    logic [31:0] ex_alu_res;
    logic [31:0] ex_mem_wdata_out;

    // EX/MEM register outputs
    logic [31:0] mem_alu_result;
    logic [31:0] mem_wdata;
    logic [4:0]  mem_rd_addr;
    logic        mem_read;
    logic        mem_write;
    logic [2:0]  mem_funct3;
    logic        mem_reg_write;
    logic [1:0]  mem_wb_sel;
    logic        mem_valid;

    // MEM stage outputs
    logic [31:0] mem_rdata;
    logic [31:0] mem_alu_out;
    logic [4:0]  mem_rd_addr_out;
    logic        mem_reg_write_out;
    logic [1:0]  mem_wb_sel_out;
    logic        mem_valid_out;

    // MEM/WB register outputs
    logic [31:0] wb_mem_rdata;
    logic [31:0] wb_alu_result;
    logic [4:0]  wb_rd_addr;
    logic        wb_reg_write;
    logic [1:0]  wb_wb_sel;
    logic        wb_valid;

    // WB stage outputs
    logic [4:0]  rf_waddr;
    logic [31:0] rf_wdata;
    logic        rf_we;
    logic [31:0] wb_result;

    // Hazard unit outputs
    logic [1:0]  fwd_alu_a;
    logic [1:0]  fwd_alu_b;

    // Stall and flush generation (simplified)
    logic        stall;
    logic        flush;

    // Forwarding data from MEM and WB stages
    logic [31:0] forward_mem_result;
    logic [31:0] forward_wb_result;

    // PC redirect logic
    logic        pc_redirect;
    logic [31:0] pc_target;

    // ========================================================================
    // Pipeline for PC+4 (needed for JAL write-back)
    // ========================================================================
    reg [31:0] pc_plus4_id, pc_plus4_ex, pc_plus4_mem, pc_plus4_wb;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            pc_plus4_id  <= 32'h0;
            pc_plus4_ex  <= 32'h0;
            pc_plus4_mem <= 32'h0;
            pc_plus4_wb  <= 32'h0;
        end else begin
            if (flush) begin
                pc_plus4_id  <= 32'h0;
                pc_plus4_ex  <= 32'h0;
                pc_plus4_mem <= 32'h0;
                pc_plus4_wb  <= 32'h0;
            end else if (!stall) begin
                pc_plus4_wb  <= pc_plus4_mem;
                pc_plus4_mem <= pc_plus4_ex;
                pc_plus4_ex  <= pc_plus4_id;
                pc_plus4_id  <= if_pc + 32'd4;
            end
            // on stall, keep values unchanged
        end
    end

    // ========================================================================
    // PC redirect mux
    // ========================================================================
    assign pc_redirect = id_pc_redirect | branch_taken;
    assign pc_target   = id_pc_redirect ? id_pc_target : branch_target;

    // ========================================================================
    // Forwarding data selects
    // ========================================================================
    assign forward_mem_result = (mem_wb_sel_out == 2'b01) ? mem_rdata : mem_alu_out;
    assign forward_wb_result  = wb_result;

    // ========================================================================
    // Assignment of simple stall and flush
    // ========================================================================
    assign stall = 1'b0;               // No stalling for simplicity
    assign flush = pc_redirect;        // Flush pipeline on any taken branch/jump

    // ========================================================================
    // Unused wires for control_unit and imm_gen (they are replicated by id_stage)
    // ========================================================================
    logic [3:0]  unused_alu_op;
    logic        unused_alu_src;
    logic        unused_mem_read;
    logic        unused_mem_write;
    logic        unused_reg_write;
    logic [1:0]  unused_wb_sel;
    logic        unused_branch;
    logic        unused_jump;
    logic        unused_jr;
    logic        unused_is_load;
    logic        unused_is_store;
    logic [2:0]  unused_funct3;
    logic [31:0] unused_imm;

    // ========================================================================
    // SUBCORE INSTANTIATIONS
    // ========================================================================

    // 1. if_stage
    if_stage u_if_stage (
        .clk         (clk),
        .rst_n       (rst_n),
        .stall       (stall),
        .flush       (flush),
        .pc_redirect (pc_redirect),
        .pc_target   (pc_target),
        .imem_addr   (imem_addr),
        .imem_rdata  (imem_rdata),
        .imem_req    (imem_req),
        .if_pc       (if_pc),
        .if_instr    (if_instr),
        .if_valid    (if_valid)
    );

    // 2. if_id_reg
    if_id_reg u_if_id_reg (
        .clk      (clk),
        .rst_n    (rst_n),
        .flush    (flush),
        .stall    (stall),
        .if_pc    (if_pc),
        .if_instr (if_instr),
        .if_valid (if_valid),
        .id_pc    (id_pc),
        .id_instr (id_instr),
        .id_valid (id_valid)
    );

    // 3. id_stage
    id_stage u_id_stage (
        .clk          (clk),
        .rst_n        (rst_n),
        .id_pc        (id_pc),
        .id_instr     (id_instr),
        .id_valid     (id_valid),
        .flush        (flush),
        .rf_rs1_addr  (rf_rs1_addr),
        .rf_rs2_addr  (rf_rs2_addr),
        .rf_rs1_data  (rf_rs1_data),
        .rf_rs2_data  (rf_rs2_data),
        .id_rs1_addr  (id_rs1_addr),
        .id_rs2_addr  (id_rs2_addr),
        .id_rs1_data  (id_rs1_data),
        .id_rs2_data  (id_rs2_data),
        .id_imm       (id_imm),
        .id_rd_addr   (id_rd_addr),
        .id_pc_out    (id_pc_out),
        .id_alu_src   (id_alu_src),
        .id_alu_op    (id_alu_op),
        .id_mem_read  (id_mem_read),
        .id_mem_write (id_mem_write),
        .id_funct3    (id_funct3),
        .id_reg_write (id_reg_write),
        .id_wb_sel    (id_wb_sel),
        .id_branch    (id_branch),
        .id_jump      (id_jump),
        .id_jr        (id_jr),
        .id_pc_redirect (id_pc_redirect),
        .id_pc_target (id_pc_target)
    );

    // 4. id_ex_reg
    id_ex_reg u_id_ex_reg (
        .clk         (clk),
        .rst_n       (rst_n),
        .flush       (flush),
        .id_rs1_addr (id_rs1_addr),
        .id_rs2_addr (id_rs2_addr),
        .id_rs1_data (id_rs1_data),
        .id_rs2_data (id_rs2_data),
        .id_imm      (id_imm),
        .id_rd_addr  (id_rd_addr),
        .id_pc       (id_pc_out),
        .id_alu_src  (id_alu_src),
        .id_alu_op   (id_alu_op),
        .id_mem_read (id_mem_read),
        .id_mem_write(id_mem_write),
        .id_funct3   (id_funct3),
        .id_reg_write(id_reg_write),
        .id_wb_sel   (id_wb_sel),
        .id_branch   (id_branch),
        .id_jump     (id_jump),
        .id_jr       (id_jr),
        .id_valid    (id_valid),
        .ex_rs1_addr (ex_rs1_addr),
        .ex_rs2_addr (ex_rs2_addr),
        .ex_rs1_data (ex_rs1_data),
        .ex_rs2_data (ex_rs2_data),
        .ex_imm      (ex_imm),
        .ex_rd_addr  (ex_rd_addr),
        .ex_pc       (ex_pc),
        .ex_alu_src  (ex_alu_src),
        .ex_alu_op   (ex_alu_op),
        .ex_mem_read (ex_mem_read),
        .ex_mem_write(ex_mem_write),
        .ex_funct3   (ex_funct3),
        .ex_reg_write(ex_reg_write),
        .ex_wb_sel   (ex_wb_sel),
        .ex_branch   (ex_branch),
        .ex_jump     (ex_jump),
        .ex_jr       (ex_jr),
        .ex_valid    (ex_valid)
    );

    // 5. ex_stage – purely combinational, no clock/reset
    ex_stage u_ex_stage (
        .ex_pc          (ex_pc),
        .ex_rs1_data    (ex_rs1_data),
        .ex_rs2_data    (ex_rs2_data),
        .ex_imm         (ex_imm),
        .ex_alu_src     (ex_alu_src),
        .ex_alu_op      (ex_alu_op),
        .ex_branch      (ex_branch),
        .ex_jump        (ex_jump),
        .ex_jr          (ex_jr),
        .ex_valid       (ex_valid),
        .fwd_alu_a      (fwd_alu_a),
        .fwd_alu_b      (fwd_alu_b),
        .fwd_mem_result (forward_mem_result),
        .fwd_wb_result  (forward_wb_result),
        .alu_a          (alu_a),
        .alu_b          (alu_b),
        .alu_op         (alu_op),
        .alu_result     (alu_result),
        .alu_zero       (alu_zero),
        .branch_taken   (branch_taken),
        .branch_target  (branch_target),
        .ex_alu_result  (ex_alu_res),
        .ex_mem_wdata   (ex_mem_wdata_out)
    );

    // 6. ex_mem_reg – control signals bypass ex_stage and come directly from ID/EX
    ex_mem_reg u_ex_mem_reg (
        .clk           (clk),
        .rst_n         (rst_n),
        .flush         (flush),
        .ex_alu_result (ex_alu_res),
        .ex_mem_wdata  (ex_mem_wdata_out),
        .ex_rd_addr    (ex_rd_addr),
        .ex_mem_read   (ex_mem_read),
        .ex_mem_write  (ex_mem_write),
        .ex_funct3     (ex_funct3),
        .ex_reg_write  (ex_reg_write),
        .ex_wb_sel     (ex_wb_sel),
        .ex_valid      (ex_valid),
        .mem_alu_result(mem_alu_result),
        .mem_wdata     (mem_wdata),
        .mem_rd_addr   (mem_rd_addr),
        .mem_read      (mem_read),
        .mem_write     (mem_write),
        .mem_funct3    (mem_funct3),
        .mem_reg_write (mem_reg_write),
        .mem_wb_sel    (mem_wb_sel),
        .mem_valid     (mem_valid)
    );

    // 7. mem_stage
    mem_stage u_mem_stage (
        .clk            (clk),
        .rst_n          (rst_n),
        .mem_alu_result (mem_alu_result),
        .mem_wdata      (mem_wdata),
        .mem_rd_addr    (mem_rd_addr),
        .mem_read       (mem_read),
        .mem_write      (mem_write),
        .mem_funct3     (mem_funct3),
        .mem_reg_write  (mem_reg_write),
        .mem_wb_sel     (mem_wb_sel),
        .mem_valid      (mem_valid),
        .dmem_addr      (dmem_addr),
        .dmem_wdata     (dmem_wdata),
        .dmem_rdata     (dmem_rdata),
        .dmem_req       (dmem_req),
        .dmem_we        (dmem_we),
        .dmem_be        (dmem_be),
        .mem_rdata      (mem_rdata),
        .mem_alu_out    (mem_alu_out),
        .mem_rd_addr_out(mem_rd_addr_out),
        .mem_reg_write_out(mem_reg_write_out),
        .mem_wb_sel_out (mem_wb_sel_out),
        .mem_valid_out  (mem_valid_out)
    );

    // 8. mem_wb_reg
    mem_wb_reg u_mem_wb_reg (
        .clk          (clk),
        .rst_n        (rst_n),
        .flush        (flush),
        .mem_rdata    (mem_rdata),
        .mem_alu_out  (mem_alu_out),
        .mem_rd_addr  (mem_rd_addr_out),
        .mem_reg_write(mem_reg_write_out),
        .mem_wb_sel   (mem_wb_sel_out),
        .mem_valid    (mem_valid_out),
        .wb_mem_rdata (wb_mem_rdata),
        .wb_alu_result(wb_alu_result),
        .wb_rd_addr   (wb_rd_addr),
        .wb_reg_write (wb_reg_write),
        .wb_wb_sel    (wb_wb_sel),
        .wb_valid     (wb_valid)
    );

    // 9. wb_stage
    wb_stage u_wb_stage (
        .clk          (clk),
        .rst_n        (rst_n),
        .wb_mem_rdata (wb_mem_rdata),
        .wb_alu_result(wb_alu_result),
        .wb_pc_plus4  (pc_plus4_wb),
        .wb_rd_addr   (wb_rd_addr),
        .wb_reg_write (wb_reg_write),
        .wb_wb_sel    (wb_wb_sel),
        .wb_valid     (wb_valid),
        .rf_waddr     (rf_waddr),
        .rf_wdata     (rf_wdata),
        .rf_we        (rf_we),
        .wb_result    (wb_result)
    );

    // 10. reg_file
    reg_file u_reg_file (
        .clk      (clk),
        .rst_n    (rst_n),
        .rs1_addr (rf_rs1_addr),
        .rs2_addr (rf_rs2_addr),
        .rs1_data (rf_rs1_data),
        .rs2_data (rf_rs2_data),
        .waddr    (rf_waddr),
        .wdata    (rf_wdata),
        .we       (rf_we)
    );

    // 11. alu
    alu u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .op     (alu_op),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // 12. imm_gen (unused – id_stage already includes it)
    imm_gen u_imm_gen (
        .instr(id_instr),
        .imm  (unused_imm)
    );

    // 13. control_unit (unused – id_stage already includes it)
    control_unit u_control_unit (
        .instr    (id_instr),
        .alu_src  (unused_alu_src),
        .alu_op   (unused_alu_op),
        .mem_read (unused_mem_read),
        .mem_write(unused_mem_write),
        .reg_write(unused_reg_write),
        .wb_sel   (unused_wb_sel),
        .branch   (unused_branch),
        .jump     (unused_jump),
        .jr       (unused_jr),
        .is_load  (unused_is_load),
        .is_store (unused_is_store),
        .funct3   (unused_funct3)
    );

    // 14. hazard_unit
    hazard_unit u_hazard_unit (
        .clk           (clk),
        .rst_n         (rst_n),
        .id_rs1_addr   (id_rs1_addr),
        .id_rs2_addr   (id_rs2_addr),
        .id_branch     (id_branch),
        .id_jump       (id_jump),
        .id_jr         (id_jr),
        .ex_rd_addr    (ex_rd_addr),
        .ex_mem_read   (ex_mem_read),
        .ex_reg_write  (ex_reg_write),
        .ex_result     (ex_alu_res),
        .mem_rd_addr   (mem_rd_addr),
        .mem_reg_write (mem_reg_write),
        .mem_result    (forward_mem_result),
        .wb_rd_addr    (wb_rd_addr),
        .wb_reg_write  (wb_reg_write),
        .wb_result     (wb_result),
        .branch_taken  (branch_taken),
        .fwd_alu_a     (fwd_alu_a),
        .fwd_alu_b     (fwd_alu_b)
    );

endmodule