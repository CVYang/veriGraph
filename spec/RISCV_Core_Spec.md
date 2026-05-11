# RV32I Single-Issue In-Order Core Specification

## 1. Overview

- **ISA**: RV32I (RV32I base integer instruction set)
- **Pipeline**: 5-stage (IF/ID/EX/MEM/WB), single-issue, in-order
- **No Cache**: Direct IMEM/DMEM access (single-cycle memory)
- **No Branch Prediction**: Stall on branches, resolve in EX stage
- **Forwarding**: EX/MEM/WB to EX (full forwarding)
- **JAL/JALR**: Resolved in ID, flush IF on taken

---

## 2. Top-Level Interface (`rv32i_core`)

```
Module: rv32i_core
Purpose: Top-level wrapper instantiating all submodules and connecting pipeline stages

Ports:
    input  logic        clk           // Clock
    input  logic        rst_n         // Active-low reset

    // Instruction Memory Interface
    output logic [31:0] imem_addr     // Instruction address
    input  logic [31:0] imem_rdata    // Instruction data (single-cycle)
    output logic        imem_req      // Instruction request

    // Data Memory Interface
    output logic [31:0] dmem_addr     // Data address
    output logic [31:0] dmem_wdata    // Data write data
    input  logic [31:0] dmem_rdata    // Data read data (single-cycle)
    output logic        dmem_req      // Data request
    output logic        dmem_we       // Write enable (1=write, 0=read)
    output logic [3:0]  dmem_be       // Byte enable
```

---

## 3. Pipeline Stage Modules

### 3.1 IF Stage (`if_stage`)

```
Module: if_stage
Purpose: Instruction fetch stage - generates PC and fetches from IMEM

Ports:
    // Clock & Reset
    input  logic        clk
    input  logic        rst_n

    // Control inputs
    input  logic        stall          // Stall IF (from hazard_unit)
    input  logic        flush          // Flush IF (from branch/jump)

    // PC redirect (from EX for branch, from ID for JAL/JALR)
    input  logic        pc_redirect    // PC redirect enable
    input  logic [31:0] pc_target      // New PC value

    // IMEM interface
    output logic [31:0] imem_addr      // Instruction address
    input  logic [31:0] imem_rdata     // Instruction data
    output logic        imem_req       // Instruction request

    // To IF/ID pipeline register
    output logic [31:0] if_pc          // Current PC
    output logic [31:0] if_instr       // Fetched instruction
    output logic        if_valid       // Instruction valid
```

### 3.2 ID Stage (`id_stage`)

```
Module: id_stage
Purpose: Instruction decode, register file read, immediate generation

Ports:
    input  logic        clk
    input  logic        rst_n

    // From IF/ID pipeline register
    input  logic [31:0] id_pc
    input  logic [31:0] id_instr
    input  logic        id_valid

    // Control inputs
    input  logic        flush          // Flush ID (from branch/jump)

    // Register file interface
    output logic [4:0]  rf_rs1_addr    // Source register 1 address
    output logic [4:0]  rf_rs2_addr    // Source register 2 address
    input  logic [31:0] rf_rs1_data    // Source register 1 data
    input  logic [31:0] rf_rs2_data    // Source register 2 data

    // Decode outputs (to ID/EX pipeline register)
    output logic [4:0]  id_rs1_addr    // Source reg 1 addr (for forwarding)
    output logic [4:0]  id_rs2_addr    // Source reg 2 addr (for forwarding)
    output logic [31:0] id_rs1_data    // Source reg 1 data
    output logic [31:0] id_rs2_data    // Source reg 2 data
    output logic [31:0] id_imm         // Immediate value
    output logic [4:0]  id_rd_addr     // Destination register addr
    output logic [31:0] id_pc_out      // PC passed through

    // Control signals (to hazard/forwarding and EX stage)
    output logic        id_alu_src     // 0=rs2, 1=imm
    output logic [3:0]  id_alu_op      // ALU operation code
    output logic        id_mem_read    // Load enable
    output logic        id_mem_write   // Store enable
    output logic [2:0]  id_funct3      // funct3 for load/store size
    output logic        id_reg_write   // Register write enable
    output logic [1:0]  id_wb_sel      // 00=ALU, 01=MEM, 10=PC+4
    output logic        id_branch      // Is branch instruction
    output logic        id_jump        // Is JAL/JALR
    output logic        id_jr          // Is JALR (use rs1+imm for target)

    // JAL/JALR PC redirect (resolved in ID)
    output logic        id_pc_redirect // PC redirect for jumps
    output logic [31:0] id_pc_target   // Jump target address
```

### 3.3 EX Stage (`ex_stage`)

```
Module: ex_stage
Purpose: Execute stage - ALU operation, branch resolution

Ports:
    input  logic        clk
    input  logic        rst_n

    // From ID/EX pipeline register
    input  logic [31:0] ex_pc
    input  logic [4:0]  ex_rs1_addr
    input  logic [4:0]  ex_rs2_addr
    input  logic [31:0] ex_rs1_data
    input  logic [31:0] ex_rs2_data
    input  logic [31:0] ex_imm
    input  logic [4:0]  ex_rd_addr
    input  logic        ex_alu_src
    input  logic [3:0]  ex_alu_op
    input  logic        ex_mem_read
    input  logic        ex_mem_write
    input  logic [2:0]  ex_funct3
    input  logic        ex_reg_write
    input  logic [1:0]  ex_wb_sel
    input  logic        ex_branch
    input  logic        ex_jump
    input  logic        ex_jr
    input  logic        ex_valid

    // Control inputs
    input  logic        flush           // Flush EX

    // Forwarding (from hazard_unit)
    input  logic [1:0]  fwd_alu_a       // Forward select for ALU operand A
    input  logic [1:0]  fwd_alu_b       // Forward select for ALU operand B
    input  logic [31:0] fwd_mem_result  // Forward data from MEM stage
    input  logic [31:0] fwd_wb_result   // Forward data from WB stage

    // ALU interface
    output logic [31:0] alu_a           // ALU operand A
    output logic [31:0] alu_b           // ALU operand B
    output logic [3:0]  alu_op          // ALU operation code
    input  logic [31:0] alu_result      // ALU result
    input  logic        alu_zero        // ALU zero flag

    // Branch resolution
    output logic        branch_taken    // Branch taken signal
    output logic [31:0] branch_target   // Branch target address

    // To EX/MEM pipeline register
    output logic [31:0] ex_alu_result   // ALU result for MEM/WB
    output logic [31:0] ex_mem_wdata    // Data to store (rs2)
    output logic [4:0]  ex_rd_addr_out  // Destination register
    output logic        ex_mem_read_out
    output logic        ex_mem_write_out
    output logic [2:0]  ex_funct3_out
    output logic        ex_reg_write_out
    output logic [1:0]  ex_wb_sel_out
    output logic        ex_valid_out
```

### 3.4 MEM Stage (`mem_stage`)

```
Module: mem_stage
Purpose: Memory access stage - load/store via DMEM

Ports:
    input  logic        clk
    input  logic        rst_n

    // From EX/MEM pipeline register
    input  logic [31:0] mem_alu_result
    input  logic [31:0] mem_wdata
    input  logic [4:0]  mem_rd_addr
    input  logic        mem_read
    input  logic        mem_write
    input  logic [2:0]  mem_funct3
    input  logic        mem_reg_write
    input  logic [1:0]  mem_wb_sel
    input  logic        mem_valid

    // DMEM interface
    output logic [31:0] dmem_addr
    output logic [31:0] dmem_wdata
    input  logic [31:0] dmem_rdata
    output logic        dmem_req
    output logic        dmem_we
    output logic [3:0]  dmem_be

    // To MEM/WB pipeline register
    output logic [31:0] mem_rdata       // Load data (after alignment and sign-extension)
    output logic [31:0] mem_alu_out     // ALU result passthrough
    output logic [4:0]  mem_rd_addr_out
    output logic        mem_reg_write_out
    output logic [1:0]  mem_wb_sel_out
    output logic        mem_valid_out
```

### 3.5 WB Stage (`wb_stage`)

```
Module: wb_stage
Purpose: Write-back stage - writes result to register file

Ports:
    input  logic        clk
    input  logic        rst_n

    // From MEM/WB pipeline register
    input  logic [31:0] wb_mem_rdata
    input  logic [31:0] wb_alu_result
    input  logic [4:0]  wb_rd_addr
    input  logic        wb_reg_write
    input  logic [1:0]  wb_wb_sel
    input  logic        wb_valid

    // Register file write interface
    output logic [4:0]  rf_waddr       // Write address
    output logic [31:0] rf_wdata       // Write data
    output logic        rf_we          // Write enable

    // Forwarding data to hazard_unit
    output logic [31:0] wb_result      // Final WB result (for forwarding)
```

---

## 4. Functional Unit Modules

### 4.1 Register File (`reg_file`)

```
Module: reg_file
Purpose: 32 x 32-bit general purpose register file (x0 hardwired to 0)

Ports:
    input  logic        clk
    input  logic        rst_n

    // Read ports (from ID stage)
    input  logic [4:0]  rs1_addr       // Read address 1
    input  logic [4:0]  rs2_addr       // Read address 2
    output logic [31:0] rs1_data       // Read data 1
    output logic [31:0] rs2_data       // Read data 2

    // Write port (from WB stage)
    input  logic [4:0]  waddr          // Write address
    input  logic [31:0] wdata          // Write data
    input  logic        we             // Write enable
```

### 4.2 ALU (`alu`)

```
Module: alu
Purpose: Arithmetic and logic unit for RV32I operations

Ports:
    input  logic [31:0] a              // Operand A
    input  logic [31:0] b              // Operand B
    input  logic [3:0]  op             // Operation code
    output logic [31:0] result         // Result
    output logic        zero           // Zero flag

    // ALU Operation Code (op):
    //   4'd0 : ADD    (a + b)
    //   4'd1 : SUB    (a - b)
    //   4'd2 : SLL    (a << b[4:0])
    //   4'd3 : SLT    (signed a < signed b)
    //   4'd4 : SLTU   (unsigned a < unsigned b)
    //   4'd5 : XOR    (a ^ b)
    //   4'd6 : SRL    (a >> b[4:0])
    //   4'd7 : SRA    (a >>> b[4:0], arithmetic)
    //   4'd8 : OR     (a | b)
    //   4'd9 : AND    (a & b)
```

### 4.3 Immediate Generator (`imm_gen`)

```
Module: imm_gen
Purpose: Extract and sign-extend immediate from instruction

Ports:
    input  logic [31:0] instr          // 32-bit instruction
    output logic [31:0] imm            // 32-bit sign-extended immediate

    // Generates appropriate immediate for:
    //   I-type (opcode[5] = 0):  {{20{instr[31]}}, instr[31:20]}
    //   S-type (opcode 0x23):   {{20{instr[31]}}, instr[31:25], instr[11:7]}
    //   B-type (opcode 0x63):   {{19{instr[31]}}, instr[31], instr[7], instr[30:25], instr[11:8], 1'b0}
    //   U-type (opcode 0x37/0x17): {instr[31:12], 12'b0}
    //   J-type (opcode 0x6F):   {{11{instr[31]}}, instr[31], instr[19:12], instr[20], instr[30:21], 1'b0}
```

### 4.4 Control Unit (`control_unit`)

```
Module: control_unit
Purpose: Decode instruction and generate control signals

Ports:
    input  logic [31:0] instr          // 32-bit instruction
    output logic        alu_src        // 0=rs2, 1=imm (for ALU mux)
    output logic [3:0]  alu_op         // ALU operation code
    output logic        mem_read       // Load instruction
    output logic        mem_write      // Store instruction
    output logic        reg_write      // Write to register file
    output logic [1:0]  wb_sel         // 00=ALU, 01=MEM, 10=PC+4
    output logic        branch         // Is branch (B-type)
    output logic        jump           // Is JAL
    output logic        jr             // Is JALR
    output logic        is_load        // Is load
    output logic        is_store       // Is store
    output logic [2:0]  funct3         // funct3 field
```

### 4.5 Hazard & Forwarding Unit (`hazard_unit`)

```
Module: hazard_unit
Purpose: Detect hazards and generate stall/flush/forwarding signals

Ports:
    input  logic        clk
    input  logic        rst_n

    // From ID stage (current instruction source registers)
    input  logic [4:0]  id_rs1_addr
    input  logic [4:0]  id_rs2_addr
    input  logic        id_branch
    input  logic        id_jump
    input  logic        id_jr

    // From EX stage (for load-use hazard detection)
    input  logic [4:0]  ex_rd_addr
    input  logic        ex_mem_read      // EX has load instruction
    input  logic        ex_reg_write

    // From MEM stage (for forwarding)
    input  logic [4:0]  mem_rd_addr
    input  logic        mem_reg_write
    input  logic [31:0] mem_result       // MEM stage result (for forwarding)

    // From WB stage (for forwarding)
    input  logic [4:0]  wb_rd_addr
    input  logic        wb_reg_write
    input  logic [31:0] wb_result        // WB stage result (for forwarding)

    // Branch/Jump resolution
    input  logic        branch_taken     // From EX stage
    input  logic        jump_taken       // From ID/EX

    // Control outputs
    output logic        stall_if         // Stall IF stage
    output logic        stall_id         // Stall ID stage
    output logic        flush_if         // Flush IF stage
    output logic        flush_id         // Flush ID stage
    output logic        flush_ex         // Flush EX stage

    // Forwarding select (to EX stage)
    output logic [1:0]  fwd_alu_a        // 00=regfile, 01=MEM, 10=WB
    output logic [1:0]  fwd_alu_b        // 00=regfile, 01=MEM, 10=WB
    output logic [31:0] fwd_mem_result   // Forward data from MEM
    output logic [31:0] fwd_wb_result    // Forward data from WB
```

---

## 5. Pipeline Registers

### 5.1 IF/ID Register (`if_id_reg`)

```
Module: if_id_reg
Purpose: Pipeline register between IF and ID stages

Ports:
    input  logic        clk, rst_n
    input  logic        flush
    input  logic        stall

    input  logic [31:0] if_pc
    input  logic [31:0] if_instr
    input  logic        if_valid

    output logic [31:0] id_pc
    output logic [31:0] id_instr
    output logic        id_valid
```

### 5.2 ID/EX Register (`id_ex_reg`)

```
Module: id_ex_reg
Purpose: Pipeline register between ID and EX stages

Ports:
    input  logic        clk, rst_n
    input  logic        flush

    // Control
    input  logic [4:0]  id_rs1_addr, id_rs2_addr
    input  logic [31:0] id_rs1_data, id_rs2_data
    input  logic [31:0] id_imm
    input  logic [4:0]  id_rd_addr
    input  logic [31:0] id_pc
    input  logic        id_alu_src
    input  logic [3:0]  id_alu_op
    input  logic        id_mem_read, id_mem_write
    input  logic [2:0]  id_funct3
    input  logic        id_reg_write
    input  logic [1:0]  id_wb_sel
    input  logic        id_branch, id_jump, id_jr
    input  logic        id_valid

    // All inputs passed through to outputs with same names, prefixed ex_*
    output logic [4:0]  ex_rs1_addr, ex_rs2_addr
    output logic [31:0] ex_rs1_data, ex_rs2_data
    output logic [31:0] ex_imm
    output logic [4:0]  ex_rd_addr
    output logic [31:0] ex_pc
    output logic        ex_alu_src
    output logic [3:0]  ex_alu_op
    output logic        ex_mem_read, ex_mem_write
    output logic [2:0]  ex_funct3
    output logic        ex_reg_write
    output logic [1:0]  ex_wb_sel
    output logic        ex_branch, ex_jump, ex_jr
    output logic        ex_valid
```

### 5.3 EX/MEM Register (`ex_mem_reg`)

```
Module: ex_mem_reg
Purpose: Pipeline register between EX and MEM stages

Ports:
    input  logic        clk, rst_n
    input  logic        flush

    input  logic [31:0] ex_alu_result
    input  logic [31:0] ex_mem_wdata
    input  logic [4:0]  ex_rd_addr
    input  logic        ex_mem_read, ex_mem_write
    input  logic [2:0]  ex_funct3
    input  logic        ex_reg_write
    input  logic [1:0]  ex_wb_sel
    input  logic        ex_valid

    // All inputs passed through with mem_* prefix
    output logic [31:0] mem_alu_result
    output logic [31:0] mem_wdata
    output logic [4:0]  mem_rd_addr
    output logic        mem_read, mem_write
    output logic [2:0]  mem_funct3
    output logic        mem_reg_write
    output logic [1:0]  mem_wb_sel
    output logic        mem_valid
```

### 5.4 MEM/WB Register (`mem_wb_reg`)

```
Module: mem_wb_reg
Purpose: Pipeline register between MEM and WB stages

Ports:
    input  logic        clk, rst_n
    input  logic        flush

    input  logic [31:0] mem_rdata
    input  logic [31:0] mem_alu_out
    input  logic [4:0]  mem_rd_addr
    input  logic        mem_reg_write
    input  logic [1:0]  mem_wb_sel
    input  logic        mem_valid

    // All inputs passed through with wb_* prefix
    output logic [31:0] wb_mem_rdata
    output logic [31:0] wb_alu_result
    output logic [4:0]  wb_rd_addr
    output logic        wb_reg_write
    output logic [1:0]  wb_wb_sel
    output logic        wb_valid
```

---

## 6. Module List Summary

| # | Module | Type | Description |
|---|--------|------|-------------|
| 1 | rv32i_core | top | Top-level wrapper |
| 2 | if_stage | stage | Instruction fetch, PC logic |
| 3 | id_stage | stage | Decode, regfile read, imm gen |
| 4 | ex_stage | stage | ALU, branch resolution |
| 5 | mem_stage | stage | Load/store, DMEM access |
| 6 | wb_stage | stage | Write-back to regfile |
| 7 | reg_file | unit | 32x32 register file |
| 8 | alu | unit | Arithmetic logic unit |
| 9 | imm_gen | unit | Immediate generator |
| 10 | control_unit | unit | Main instruction decoder |
| 11 | hazard_unit | unit | Hazard detection, forwarding, stall/flush |
| 12 | if_id_reg | pipeline_reg | IF/ID pipeline register |
| 13 | id_ex_reg | pipeline_reg | ID/EX pipeline register |
| 14 | ex_mem_reg | pipeline_reg | EX/MEM pipeline register |
| 15 | mem_wb_reg | pipeline_reg | MEM/WB pipeline register |

---

## 7. Instruction Support (RV32I)

All 37 standard RV32I instructions:

| Type | Instructions |
|------|-------------|
| R-type | ADD, SUB, AND, OR, XOR, SLL, SRL, SRA, SLT, SLTU |
| I-type | ADDI, ANDI, ORI, XORI, SLLI, SRLI, SRAI, SLTI, SLTIU, LB, LH, LW, LBU, LHU, JALR |
| S-type | SB, SH, SW |
| B-type | BEQ, BNE, BLT, BGE, BLTU, BGEU |
| U-type | LUI, AUIPC |
| J-type | JAL |
