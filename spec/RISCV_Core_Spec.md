# RISC-V Core Specification

**Document Version:** 1.0
**Date:** 2026-04-26
**Architecture:** RV32GC (RV32I + M + A + F + D + C)
**Target:** General Purpose Processor

---

## 1. Overview

### 1.1 Target Application
High-performance general purpose processor for embedded and mobile applications.

### 1.2 Key Features
- 2-way superscalar issue and execution
- 8-stage pipeline with branch prediction
- Separate I-cache and D-cache
- Integer ALU, Floating-point Unit (FPU), Load/Store Unit
- Support for RISC-V ISA extensions: M, A, F, D, C

---

## 2. Architecture Overview

### 2.1 ISA Support
| Extension | Description | Status |
|-----------|-------------|--------|
| I | Base Integer Instructions | Required |
| M | Integer Multiplication/Division | Required |
| A | Atomic Instructions | Required |
| F | Single-Precision Floating Point | Required |
| D | Double-Precision Floating Point | Required |
| C | Compressed Instructions | Required |

### 2.2 Privilege Modes
- Machine Mode (M-mode)
- User Mode (U-mode) - future extension

### 2.3 Physical Memory Attributes (PMA)
- Main Memory (cacheable)
- I/O Devices (non-cacheable)
- ROM (cacheable for instruction fetch)

---

## 3. Pipeline Architecture

### 3.1 Pipeline Stages

```
Stage 1: IF1 - Instruction Fetch 1 (PC calculation, instruction cache access)
Stage 2: IF2 - Instruction Fetch 2 (Instruction alignment, branch prediction)
Stage 3: ID  - Instruction Decode (Decode, register file read)
Stage 4: IS  - Issue Queue (Instruction issue to execution units)
Stage 5: EX1 - Execution Stage 1 (ALU operation, effective address calculation)
Stage 6: EX2 - Execution Stage 2 (Multi-cycle operations, branch resolution)
Stage 7: MEM - Memory Access (Load/Store to data cache)
Stage 8: WB  - Write Back (Result write-back to register file)
```

### 3.2 Superscalar Organization

| Issue Slot | Lane 0 | Lane 1 |
|------------|--------|--------|
| Issue Width | 2 instructions per cycle | |
| Dispatch    | In-order | In-order |
| Execution   | Out-of-order completion | Out-of-order completion |
| Commit      | In-order (write-back) | In-order (write-back) |

### 3.3 Execution Units

| Unit | Quantity | Latency | Operations |
|------|----------|---------|------------|
| Integer ALU | 1 | 1 cycle | ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA, etc. |
| Integer Mul | 1 | 3 cycles | MUL, MULH, MULHU, MULHSU |
| Integer Div | 1 | 5 cycles (pipelined) | DIV, DIVU, REM, REMU |
| Branch Unit | 1 | 1-2 cycles | JAL, JALR, B-type |
| FPU (SP) | 1 | 4 cycles | FADD.S, FSUB.S, FMUL.S, FDIV.S, etc. |
| FPU (DP) | 1 | 5 cycles | FADD.D, FSUB.D, FMUL.D, FDIV.D, etc. |
| Load/Store | 1 | 2-4 cycles | LB, LH, LW, LBU, LHU, SB, SH, SW, etc. |
| Atomic | 1 | 4-6 cycles | LR, SC, AMO ops |

---

## 4. Branch Prediction

### 4.1 Branch Predictor Types

| Predictor | Configuration | Description |
|-----------|---------------|-------------|
| BTB | 128 entries | Branch Target Buffer |
| BHT | 64 entries | Branch History Table (2-bit saturating counter) |
| RAS | 8 entries | Return Address Stack |
| GShare | 128 entries | Global History Branch Predictor (optional) |

### 4.2 Branch Resolution
- Branch direction resolved in EX1 stage
- Branch target resolved in EX1 stage
- Misprediction penalty: 3 cycles (flush IF1, IF2 stages)

### 4.3 Branch Prediction Accuracy Target
- Target accuracy: > 90%
- Mispredict rate: < 5%

---

## 5. Cache System

### 5.1 L1 Instruction Cache (I-Cache)

| Parameter | Value |
|-----------|-------|
| Size | 16 KB |
| Associativity | 4-way |
| Line Size | 64 bytes |
| Hit Latency | 1 cycle |
| Miss Penalty | ~10 cycles (to main memory) |
| Replacement Policy | LRU |
| Write Policy | Read-allocate, write-no-allocate |

### 5.2 L1 Data Cache (D-Cache)

| Parameter | Value |
|-----------|-------|
| Size | 16 KB |
| Associativity | 4-way |
| Line Size | 64 bytes |
| Hit Latency | 1 cycle |
| Miss Penalty | ~10 cycles (to main memory) |
| Replacement Policy | LRU |
| Write Policy | Write-back |
| Write Buffer | 4 entries |

### 5.3 Cache Coherency
- No coherency protocol (single core)
- Memory coherency maintained by software

### 5.4 L2 Cache (Unified)

| Parameter | Value |
|-----------|-------|
| Size | 256 KB |
| Associativity | 8-way |
| Line Size | 64 bytes |
| Hit Latency | 3 cycles |
| Miss Penalty | ~20 cycles (to main memory) |
| Replacement Policy | LRU |
| Write Policy | Write-back |
| Coherency | Snooping (future AMBA compliance) |

### 5.5 Memory Interface

| Parameter | Value |
|-----------|-------|
| Memory Data Width | 64-bit |
| Memory Address Width | 32-bit |
| Maximum Memory Size | 4 GB |
| Supports unaligned access | Yes (trapped) |

---

## 6. Execution Units Detail

### 6.1 Integer ALU
- Single-cycle operations
- Supports all RISC-V I-extension instructions
- Zero cycle latency (result available next stage)

### 6.2 Integer Multiplier/Divider
- Pipelined multiplier: 3 cycle latency
- Pipelined divider: 5 cycle latency
- Supports M-extension instructions

### 6.3 Floating-Point Unit (FPU)

| Feature | Single Precision (F) | Double Precision (D) |
|---------|---------------------|---------------------|
| Latency | 4 cycles | 5 cycles |
| Throughput | 1 per cycle | 1 per 2 cycles |
| Pipeline Depth | 4 | 5 |
| Exception Handling | Yes | Yes |
| Rounding Modes | All 5 RISC-V modes | All 5 RISC-V modes |
| NaN Handling | IEEE 754 compliant | IEEE 754 compliant |

**FPU Register File:**
- 32 registers (f0-f31)
- Each register: 32 bits (F), 64 bits (D)
- Dual-port read, single-port write

### 6.4 Load/Store Unit

| Parameter | Value |
|-----------|-------|
| Load Latency | 2 cycles (cache hit) |
| Store Latency | 1 cycle (cache hit, write buffer) |
| Address Generation | Base + offset (signed/unsigned) |
| Alignment | Supports word and halfword alignment |
| Unaligned Access | Trapped (U-mode) |

**Supported Load Instructions:** LB, LBU, LH, LHU, LW, FLW, FLD
**Supported Store Instructions:** SB, SH, SW, FSW, FSD

### 6.5 Atomic Unit
- Supports LR/SC sequences
- Supports AMO operations: AMOSWAP, AMOADD, AMOAND, AMOOR, AMOXOR, AMOMIN, AMOMAX, AMOMINU, AMOMAXU
- Atomic operation latency: 4-6 cycles

---

## 7. Register Files

### 7.1 Integer Register File

| Parameter | Value |
|-----------|-------|
| Registers | 32 (x0-x31) |
| Register Width | 32 bits |
| Read Ports | 4 (2 read ports x 2 lanes) |
| Write Ports | 2 (1 per lane) |
| x0 Read | Always returns 0 |
| x0 Write | Discarded |

### 7.2 Floating-Point Register File

| Parameter | Value |
|-----------|-------|
| Registers | 32 (f0-f31) |
| Register Width | 64 bits (D extension) |
| Read Ports | 4 (2 read ports x 2 lanes) |
| Write Ports | 2 (1 per lane) |
| f0 Read | Normal read (not constant zero) |

### 7.3 Control and Status Registers (CSRs)

**Required CSRs:**
- MTVEC (Machine Trap Vector)
- MEPC (Machine Exception PC)
- MCAUSE (Machine Cause)
- MTVAL (Machine Trap Value)
- MSTATUS (Machine Status)
- MISA (Machine ISA)
- MHARTID (Hardware Thread ID)
- MCYCLE (Machine Cycle Counter)
- MINSTRET (Machine Instructions Retired)

---

## 8. Interrupt and Exception Handling

### 8.1 Exception Types

| Exception Code | Description |
|----------------|-------------|
| 0 | Instruction address misaligned |
| 1 | Instruction access fault |
| 2 | Illegal instruction |
| 3 | Breakpoint |
| 4 | Load address misaligned |
| 5 | Load access fault |
| 6 | Store/AMO address misaligned |
| 7 | Store/AMO access fault |
| 8 | Environment call from U-mode |
| 9 | Environment call from M-mode |
| 11 | Instruction page fault |
| 13 | Load page fault |
| 15 | Store/AMO page fault |

### 8.2 Interrupt Types

| Interrupt Code | Description |
|----------------|-------------|
| 1 | Software interrupt (MSWINT) |
| 2 | Hart software interrupt |
| 3 | Timer interrupt (MTIME) |
| 7 | Machine external interrupt |

### 8.3 Interrupt Latency
- Interrupt detection: 1 cycle
- Interrupt vectoring: 2 cycles
- Total interrupt latency: 3-5 cycles

---

## 9. Clock and Power

### 9.1 Target Clock Frequency
- Target frequency: 200 MHz
- Maximum frequency: 400 MHz

### 9.2 Performance Targets
- Target: 2.5 DMIPS/MHz (typical)
- Range: 2-3 DMIPS/MHz
- CoreMark target: > 3.0 CoreMark/MHz (estimated)

### 9.3 Power Management
- Clock gating for idle units
- Dynamic frequency scaling (future)
- Power domain isolation

### 9.3 Process Node
- Target: TSMC 28nm (or equivalent)
- Typical voltage: 1.0V - 1.2V

---

## 10. Interface Signals

### 10.1 Clock and Reset
| Signal | Direction | Description |
|--------|-----------|-------------|
| clk | Input | System clock |
| rst_n | Input | Active-low reset |

### 10.2 Memory Interface
| Signal | Direction | Description |
|--------|-----------|-------------|
| imem_req_valid | Output | Instruction memory request valid |
| imem_req_addr | Output | Instruction memory address |
| imem_req_ready | Input | Instruction memory ready |
| imem_resp_valid | Input | Instruction memory response valid |
| imem_resp_data | Input | Instruction memory data |
| dmem_req_valid | Output | Data memory request valid |
| dmem_req_addr | Output | Data memory address |
| dmem_req_we | Output | Data memory write enable |
| dmem_req_be | Output | Data memory byte enable |
| dmem_req_wdata | Output | Data memory write data |
| dmem_resp_valid | Input | Data memory response valid |
| dmem_resp_rdata | Input | Data memory read data |

### 10.3 Interrupt Interface
| Signal | Direction | Description |
|--------|-----------|-------------|
| mti | Input | Machine timer interrupt |
| mei | Input | Machine external interrupt |
| msi | Input | Machine software interrupt |

### 10.4 Debug Interface
| Signal | Direction | Description |
|--------|-----------|-------------|
| debug_halt | Input | Debug halt request |
| debug_resume | Input | Debug resume request |
| debug_pc | Output | Current program counter |
| debug_state | Output | Debug state |

---

## 11. Verification Plan

### 11.1 Verification Levels
1. **Unit Level**: Individual execution unit verification
2. **Pipeline Level**: Stage-by-stage verification
3. **Core Level**: Full core verification with random instruction sequences
4. **SoC Level**: Integration verification

### 11.2 Test Suites
- RISC-V Architecture Test Suite (riscv-tests)
- RISC-V Compliance Test Suite
- Custom directed tests for each execution unit
- Random instruction stream generator

### 11.3 Coverage Metrics
- Functional coverage: > 95%
- Code coverage: > 90%
- Branch coverage: 100%

---

## 12. Implementation Milestones

| Phase | Description | Duration |
|-------|-------------|----------|
| Phase 1 | ISA Decoder and Register Files | 4 weeks |
| Phase 2 | Integer Execution Units (ALU, Mul, Div) | 4 weeks |
| Phase 3 | Pipeline Integration and BPU | 6 weeks |
| Phase 4 | FPU Implementation | 6 weeks |
| Phase 5 | Cache Subsystem | 6 weeks |
| Phase 6 | Load/Store and Atomic Units | 4 weeks |
| Phase 7 | Integration and Verification | 8 weeks |
| Phase 8 | FPGA Prototype and Validation | 4 weeks |

**Total Estimated Duration:** ~42 weeks (10 months)

---

## 13. Open Questions

1. **Cache Size**: 16KB I-cache and 16KB D-cache - acceptable for target application?
2. **BTB/BHT Size**: Current values (128/64 entries) - should we increase?
3. **L2 Cache**: ~~Is L2 cache required? If yes, what size/associativity?~~ **RESOLVED: 256KB 8-way**
4. **Hardware Multiply/Divide**: ~~Should div be iterative (slow) or pipelined (fast)?~~ **RESOLVED: Pipelined divider (5 cycles)**
5. **Debug Module**: What debug features are required (trigger, trace)?
6. **Performance Targets**: ~~Specific DMIPS or CoreMark targets?~~ **RESOLVED: 2-3 DMIPS/MHz**
7. **Fabric Interface**: AXI, AHB, or custom? What width?

---

## 14. Document History

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-04-26 | - | Initial version |

---

*This specification is a living document and will be updated as design progresses.*
