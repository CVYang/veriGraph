module rv32i_core (
    input  logic        clk,
    input  logic        rst_n,
    output logic [31:0] imem_addr,
    input  logic [31:0] imem_rdata,
    output logic        imem_req,
    output logic [31:0] dmem_addr,
    output logic [31:0] dmem_wdata,
    input  logic [31:0] dmem_rdata,
    output logic        dmem_req,
    output logic        dmem_we,
    output logic [3:0]  dmem_be
);

    // Pipeline control signals from hazard unit
    wire        stall_if;
    wire        stall_id;
    wire        flush_if;
    wire        flush_id;
    wire        flush_ex;

    // Forwarding signals
    wire [1:0]  fwd_alu_a;
    wire [1:0]  fwd_alu_b;
    wire [31:0] fwd_mem_result;
    wire [31:0] fwd_wb_result;

    // IF/ID pipeline signals
    wire [31:0] if_pc;
    wire [31:0] if_instr;
    wire        if_valid;

    wire [31:0] id_pc;
    wire [31:0] id_instr;
    wire        id_valid;

    // ID/EX pipeline signals
    wire [4:0]  ex_rs1_addr;
    wire [4:0]  ex_rs2_addr;
    wire [31:0] ex_rs1_data;
    wire [31:0] ex_rs2_data;
    wire [31:0] ex_imm;
    wire [4:0]  ex_rd_addr;
    wire [31:0] ex_pc;
    wire        ex_alu_src;
    wire [3:0]  ex_alu_op;
    wire        ex_mem_read;
    wire        ex_mem_write;
    wire [2:0]  ex_funct3;
    wire        ex_reg_write;
    wire [1:0]  ex_wb_sel;
    wire        ex_branch;
    wire        ex_jump;
    wire        ex_jr;
    wire        ex_valid;

    // EX/MEM pipeline signals
    wire [31:0] mem_alu_result;
    wire [31:0] mem_wdata;
    wire [4:0]  mem_rd_addr;
    wire        mem_read;
    wire        mem_write;
    wire [2:0]  mem_funct3;
    wire        mem_reg_write;
    wire [1:0]  mem_wb_sel;
    wire        mem_valid;

    // MEM/WB pipeline signals
    wire [31:0] wb_mem_rdata;
    wire [31:0] wb_alu_result;
    wire [4:0]  wb_rd_addr;
    wire        wb_reg_write;
    wire [1:0]  wb_wb_sel;
    wire        wb_valid;

    // Register file signals
    wire [4:0]  rf_rs1_addr;
    wire [4:0]  rf_rs2_addr;
    wire [31:0] rf_rs1_data;
    wire [31:0] rf_rs2_data;
    wire [4:0]  rf_waddr;
    wire [31:0] rf_wdata;
    wire        rf_we;

    // ID stage signals
    wire [4:0]  id_rs1_addr;
    wire [4:0]  id_rs2_addr;
    wire [31:0] id_rs1_data;
    wire [31:0] id_rs2_data;
    wire [31:0] id_imm;
    wire [4:0]  id_rd_addr;
    wire        id_alu_src;
    wire [3:0]  id_alu_op;
    wire        id_mem_read;
    wire        id_mem_write;
    wire [2:0]  id_funct3;
    wire        id_reg_write;
    wire [1:0]  id_wb_sel;
    wire        id_branch;
    wire        id_jump;
    wire        id_jr;
    wire        id_pc_redirect;
    wire [31:0] id_pc_target;

    // EX stage internal signals
    wire [31:0] alu_a;
    wire [31:0] alu_b;
    wire [3:0]  alu_op;
    wire [31:0] alu_result;
    wire        alu_zero;
    wire        branch_taken;
    wire [31:0] branch_target;
    wire [31:0] ex_alu_result_out;
    wire [31:0] ex_mem_wdata_out;
    wire [4:0]  ex_rd_addr_out;
    wire        ex_mem_read_out;
    wire        ex_mem_write_out;
    wire [2:0]  ex_funct3_out;
    wire        ex_reg_write_out;
    wire [1:0]  ex_wb_sel_out;
    wire        ex_valid_out;

    // WB stage signals
    wire [4:0]  wb_rf_waddr;
    wire [31:0] wb_rf_wdata;
    wire        wb_rf_we;
    wire [31:0] wb_result;

    // Branch/jump taken signals
    wire        jump_taken;
    wire        pc_redirect;
    wire [31:0] pc_target;

    // Stall signal for IF stage
    wire        stall;
    assign stall = stall_if;

    // PC redirect and target for branches/jumps
    assign pc_redirect = branch_taken || jump_taken || id_pc_redirect;
    assign pc_target = id_pc_redirect ? id_pc_target : branch_target;

    assign jump_taken = id_jump || id_jr;

    // =====================================================
    // IF Stage
    // =====================================================
    if_stage u_if_stage (
        .clk          (clk),
        .rst_n        (rst_n),
        .stall        (stall),
        .flush        (flush_if),
        .pc_redirect  (pc_redirect),
        .pc_target    (pc_target),
        .imem_addr    (imem_addr),
        .imem_rdata   (imem_rdata),
        .imem_req     (imem_req),
        .if_pc        (if_pc),
        .if_instr     (if_instr),
        .if_valid     (if_valid)
    );

    // =====================================================
    // IF/ID Pipeline Register
    // =====================================================
    if_id_reg u_if_id_reg (
        .clk        (clk),
        .rst_n      (rst_n),
        .flush      (flush_id),
        .stall      (stall_id),
        .if_pc      (if_pc),
        .if_instr   (if_instr),
        .if_valid   (if_valid),
        .id_pc      (id_pc),
        .id_instr   (id_instr),
        .id_valid   (id_valid)
    );

    // =====================================================
    // Register File
    // =====================================================
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

    // =====================================================
    // ID Stage
    // =====================================================
    id_stage u_id_stage (
        .clk           (clk),
        .rst_n         (rst_n),
        .id_pc         (id_pc),
        .id_instr      (id_instr),
        .id_valid      (id_valid),
        .flush         (flush_id),
        .rf_rs1_data   (rf_rs1_data),
        .rf_rs2_data   (rf_rs2_data),
        .rf_rs1_addr   (rf_rs1_addr),
        .rf_rs2_addr   (rf_rs2_addr),
        .id_rs1_addr   (id_rs1_addr),
        .id_rs2_addr   (id_rs2_addr),
        .id_rs1_data   (id_rs1_data),
        .id_rs2_data   (id_rs2_data),
        .id_imm        (id_imm),
        .id_rd_addr    (id_rd_addr),
        .id_pc_out     (),
        .id_alu_src    (id_alu_src),
        .id_alu_op     (id_alu_op),
        .id_mem_read   (id_mem_read),
        .id_mem_write  (id_mem_write),
        .id_funct3     (id_funct3),
        .id_reg_write  (id_reg_write),
        .id_wb_sel     (id_wb_sel),
        .id_branch     (id_branch),
        .id_jump       (id_jump),
        .id_jr         (id_jr),
        .id_pc_redirect(id_pc_redirect),
        .id_pc_target  (id_pc_target)
    );

    // =====================================================
    // ID/EX Pipeline Register
    // =====================================================
    id_ex_reg u_id_ex_reg (
        .clk           (clk),
        .rst_n         (rst_n),
        .flush         (flush_ex),
        .id_rs1_addr   (id_rs1_addr),
        .id_rs2_addr   (id_rs2_addr),
        .id_rs1_data   (id_rs1_data),
        .id_rs2_data   (id_rs2_data),
        .id_imm        (id_imm),
        .id_rd_addr    (id_rd_addr),
        .id_pc         (id_pc),
        .id_alu_src    (id_alu_src),
        .id_alu_op     (id_alu_op),
        .id_mem_read   (id_mem_read),
        .id_mem_write  (id_mem_write),
        .id_funct3     (id_funct3),
        .id_reg_write  (id_reg_write),
        .id_wb_sel     (id_wb_sel),
        .id_branch     (id_branch),
        .id_jump       (id_jump),
        .id_jr         (id_jr),
        .id_valid      (id_valid),
        .ex_rs1_addr   (ex_rs1_addr),
        .ex_rs2_addr   (ex_rs2_addr),
        .ex_rs1_data   (ex_rs1_data),
        .ex_rs2_data   (ex_rs2_data),
        .ex_imm        (ex_imm),
        .ex_rd_addr    (ex_rd_addr),
        .ex_pc         (ex_pc),
        .ex_alu_src    (ex_alu_src),
        .ex_alu_op     (ex_alu_op),
        .ex_mem_read   (ex_mem_read),
        .ex_mem_write  (ex_mem_write),
        .ex_funct3     (ex_funct3),
        .ex_reg_write  (ex_reg_write),
        .ex_wb_sel     (ex_wb_sel),
        .ex_branch     (ex_branch),
        .ex_jump       (ex_jump),
        .ex_jr         (ex_jr),
        .ex_valid      (ex_valid)
    );

    // =====================================================
    // ALU
    // =====================================================
    alu u_alu (
        .a      (alu_a),
        .b      (alu_b),
        .op     (alu_op),
        .result (alu_result),
        .zero   (alu_zero)
    );

    // =====================================================
    // EX Stage
    // =====================================================
    ex_stage u_ex_stage (
        .clk              (clk),
        .rst_n            (rst_n),
        .ex_pc            (ex_pc),
        .ex_rs1_addr      (ex_rs1_addr),
        .ex_rs2_addr      (ex_rs2_addr),
        .ex_rs1_data      (ex_rs1_data),
        .ex_rs2_data      (ex_rs2_data),
        .ex_imm           (ex_imm),
        .ex_rd_addr       (ex_rd_addr),
        .ex_alu_src       (ex_alu_src),
        .ex_alu_op        (ex_alu_op),
        .ex_mem_read      (ex_mem_read),
        .ex_mem_write     (ex_mem_write),
        .ex_funct3        (ex_funct3),
        .ex_reg_write     (ex_reg_write),
        .ex_wb_sel        (ex_wb_sel),
        .ex_branch        (ex_branch),
        .ex_jump          (ex_jump),
        .ex_jr            (ex_jr),
        .ex_valid         (ex_valid),
        .flush            (flush_ex),
        .fwd_alu_a        (fwd_alu_a),
        .fwd_alu_b        (fwd_alu_b),
        .fwd_mem_result   (fwd_mem_result),
        .fwd_wb_result    (fwd_wb_result),
        .alu_a            (alu_a),
        .alu_b            (alu_b),
        .alu_op           (alu_op),
        .alu_result       (alu_result),
        .alu_zero         (alu_zero),
        .branch_taken     (branch_taken),
        .branch_target    (branch_target),
        .ex_alu_result    (ex_alu_result_out),
        .ex_mem_wdata     (ex_mem_wdata_out),
        .ex_rd_addr_out   (ex_rd_addr_out),
        .ex_mem_read_out  (ex_mem_read_out),
        .ex_mem_write_out (ex_mem_write_out),
        .ex_funct3_out    (ex_funct3_out),
        .ex_reg_write_out (ex_reg_write_out),
        .ex_wb_sel_out    (ex_wb_sel_out),
        .ex_valid_out     (ex_valid_out)
    );

    // =====================================================
    // EX/MEM Pipeline Register
    // =====================================================
    ex_mem_reg u_ex_mem_reg (
        .clk            (clk),
        .rst_n          (rst_n),
        .flush          (1'b0),
        .ex_alu_result  (ex_alu_result_out),
        .ex_mem_wdata   (ex_mem_wdata_out),
        .ex_rd_addr     (ex_rd_addr_out),
        .ex_mem_read    (ex_mem_read_out),
        .ex_mem_write   (ex_mem_write_out),
        .ex_funct3      (ex_funct3_out),
        .ex_reg_write   (ex_reg_write_out),
        .ex_wb_sel      (ex_wb_sel_out),
        .ex_valid       (ex_valid_out),
        .mem_alu_result (mem_alu_result),
        .mem_wdata      (mem_wdata),
        .mem_rd_addr    (mem_rd_addr),
        .mem_read       (mem_read),
        .mem_write      (mem_write),
        .mem_funct3     (mem_funct3),
        .mem_reg_write  (mem_reg_write),
        .mem_wb_sel     (mem_wb_sel),
        .mem_valid      (mem_valid)
    );

    // =====================================================
    // MEM Stage
    // =====================================================
    mem_stage u_mem_stage (
        .clk             (clk),
        .rst_n           (rst_n),
        .mem_alu_result  (mem_alu_result),
        .mem_wdata       (mem_wdata),
        .mem_rd_addr     (mem_rd_addr),
        .mem_read        (mem_read),
        .mem_write       (mem_write),
        .mem_funct3      (mem_funct3),
        .mem_reg_write   (mem_reg_write),
        .mem_wb_sel      (mem_wb_sel),
        .mem_valid       (mem_valid),
        .dmem_addr       (dmem_addr),
        .dmem_wdata      (dmem_wdata),
        .dmem_rdata      (dmem_rdata),
        .dmem_req        (dmem_req),
        .dmem_we         (dmem_we),
        .dmem_be         (dmem_be),
        .mem_rdata       (wb_mem_rdata),
        .mem_alu_out     (wb_alu_result),
        .mem_rd_addr_out (wb_rd_addr),
        .mem_reg_write_out(wb_reg_write),
        .mem_wb_sel_out  (wb_wb_sel),
        .mem_valid_out   (wb_valid)
    );

    // =====================================================
    // MEM/WB Pipeline Register
    // =====================================================
    mem_wb_reg u_mem_wb_reg (
        .clk           (clk),
        .rst_n         (rst_n),
        .flush         (1'b0),
        .mem_rdata     (wb_mem_rdata),
        .mem_alu_out   (wb_alu_result),
        .mem_rd_addr   (wb_rd_addr),
        .mem_reg_write (wb_reg_write),
        .mem_wb_sel    (wb_wb_sel),
        .mem_valid     (wb_valid),
        .wb_mem_rdata  (wb_mem_rdata),
        .wb_alu_result (wb_alu_result),
        .wb_rd_addr    (wb_rd_addr),
        .wb_reg_write  (wb_reg_write),
        .wb_wb_sel     (wb_wb_sel),
        .wb_valid      (wb_valid)
    );

    // =====================================================
    // WB Stage
    // =====================================================
    wb_stage u_wb_stage (
        .clk          (clk),
        .rst_n        (rst_n),
        .wb_mem_rdata (wb_mem_rdata),
        .wb_alu_result(wb_alu_result),
        .wb_rd_addr   (wb_rd_addr),
        .wb_reg_write (wb_reg_write),
        .wb_wb_sel    (wb_wb_sel),
        .wb_valid     (wb_valid),
        .rf_waddr     (rf_waddr),
        .rf_wdata     (rf_wdata),
        .rf_we        (rf_we),
        .wb_result    (wb_result)
    );

    // =====================================================
    // Hazard Unit
    // =====================================================
    hazard_unit u_hazard_unit (
        .clk             (clk),
        .rst_n           (rst_n),
        .id_rs1_addr     (id_rs1_addr),
        .id_rs2_addr     (id_rs2_addr),
        .id_branch       (id_branch),
        .id_jump         (id_jump),
        .id_jr           (id_jr),
        .ex_rd_addr      (ex_rd_addr_out),
        .ex_mem_read     (ex_mem_read_out),
        .ex_reg_write    (ex_reg_write_out),
        .mem_rd_addr     (mem_rd_addr),
        .mem_reg_write   (mem_reg_write),
        .mem_result      (mem_alu_result),
        .wb_rd_addr      (wb_rd_addr),
        .wb_reg_write    (wb_reg_write),
        .wb_result       (wb_result),
        .branch_taken    (branch_taken),
        .jump_taken      (jump_taken),
        .stall_if        (stall_if),
        .stall_id        (stall_id),
        .flush_if        (flush_if),
        .flush_id        (flush_id),
        .flush_ex        (flush_ex),
        .fwd_alu_a       (fwd_alu_a),
        .fwd_alu_b       (fwd_alu_b),
        .fwd_mem_result  (fwd_mem_result),
        .fwd_wb_result   (fwd_wb_result)
    );

endmodule