# Multi-Agent：从 Spec 到 Netlist，用 AI 全自动生成一颗 RISC-V 处理器

> 从一份 Markdown 规格文档出发，五个 AI Agent 协作，自动生成 15 个 Verilog 模块，通过编译、仿真、综合，最终产出 285 个逻辑单元的门级网表。本文完整复盘这个系统的架构设计、Agent 编排策略、失败案例和经验教训。
>
> 本文基于 VeriGraph 项目的原始论文 *"VeriGraph: A Multi-Agent Framework for Automated RTL Generation"*（arXiv:2604.14550）的工程实现，深入剖析从论文到落地过程中遇到的实际问题和解决方案。

---

## 引言：为什么做这件事

芯片设计领域有一个公认的痛点：**RTL 代码编写效率极低**。一个 RV32I 五级流水线处理器核心，经验丰富的工程师需要 2-4 周才能完成编码和初步验证。而大语言模型（LLM）在代码生成上展现出了惊人的能力——GitHub Copilot 可以补全函数，ChatGPT 可以写 Python 脚本。

那么，**能不能让 AI 自动生成一颗完整的处理器**？

答案是：能，但有前提。

本文复盘 VeriGraph 项目——一个基于 CrewAI 多智能体框架的 RTL 自动生成系统。它从一份 547 行的 RISC-V 规格文档出发，自动生成 15 个 Verilog 模块，经过编译、仿真、综合的完整 EDA 流程，最终产出一颗可综合的 RV32I 处理器核心。

---

## 第一部分：系统架构全貌

### 1.1 技术栈

| 层次 | 技术选型 | 用途 |
|------|---------|------|
| 多智能体框架 | CrewAI 1.14 | Agent 定义、任务编排、执行管理 |
| 大语言模型 | DeepSeek V4 Pro | 代码生成、规格分析、代码审查 |
| API 网关 | LiteLLM | 统一多个 LLM 提供商的 API 调用 |
| 仿真编译 | Icarus Verilog (iverilog v10) | Verilog 编译和功能仿真 |
| 波形生成 | vvp (Icarus runtime) | 执行仿真并导出 VCD 波形 |
| 逻辑综合 | Yosys 0.35 | RTL 到门级网表的综合 |
| 可视化 | 纯 SVG + HTML | 知识图谱、模块依赖图 |
| 配置管理 | YAML | 流水线参数、LLM 参数 |

### 1.2 目标产物：RV32I 五级流水线处理器

目标是一个 **RV32I 单发射顺序五级流水线核心**，包含：

- **5 个流水线级**：IF（取指）、ID（译码）、EX（执行）、MEM（访存）、WB（写回）
- **4 个流水线寄存器**：IF/ID、ID/EX、EX/MEM、MEM/WB
- **5 个功能单元**：ALU、寄存器文件、立即数生成器、控制单元、Hazard/Forwarding 单元
- **1 个顶层封装**：rv32i_core，实例化并连接所有子模块

共计 **15 个 Verilog 模块**，支持 RV32I 全部 37 条指令。

### 1.3 系统架构图

```
                         spec/RISCV_Core_Spec.md
                         (547行设计规格文档)
                                 │
        ┌────────────────────────┼────────────────────────┐
        │              CrewAI Multi-Agent 层                │
        │                                                  │
        │  ┌──────────┐   ┌──────────┐   ┌──────────┐    │
        │  │  Spec    │   │   RTL    │   │  Code    │    │
        │  │ Analyst  │──→│ Designer │──→│ Reviewer │    │
        │  │  (分析)   │   │  (生成)   │   │  (审查)   │    │
        │  └──────────┘   └────┬─────┘   └────┬─────┘    │
        │                      │               │          │
        │                      │    ┌──────────┴──────┐   │
        │                      │    │  Testbench       │   │
        │                      └────│  Generator       │   │
        │                           │  (验证用例)       │   │
        │                           └────────┬─────────┘   │
        │                                    │              │
        │                           ┌────────┴──────────┐  │
        │                           │  Integration      │  │
        │                           │  Architect        │  │
        │                           │  (顶层集成)        │  │
        │                           └────────┬──────────┘  │
        └────────────────────────────────────┼─────────────┘
                                             │
        ┌────────────────────────────────────┼─────────────┐
        │                    EDA 工具链层                    │
        │                                                  │
        │   iverilog 语法检查  →  iverilog 全量编译         │
        │         ↓                        ↓               │
        │   vvp 功能仿真  →  VCD 波形导出  →  yosys 综合   │
        │                                                  │
        │   产物: .v源码 + _tb.v验证 + .vcd波形 + .v网表    │
        └──────────────────────────────────────────────────┘
```

---

## 第二部分：五个 Agent 的详细设计

CrewAI 中的 Agent 是具备特定角色、目标和专业知识的 AI 实体。本项目定义了 5 个 Agent，**每个 Agent 只做一件事**，通过严格的输入输出协议协作。

### 2.1 Spec Analyst — 规格分析员

**角色定义：**
- Role：Hardware Specification Analyst
- Backstory：拥有 20 年 RISC-V 处理器设计经验的资深硬件架构师

**核心任务：** 将 547 行 Markdown 规格文档解析为 **15 个结构化的 JSON 对象**。

**为什么需要这个 Agent？** 直接让 LLM 阅读整个 Markdown 文档并生成代码，上下文过长（547 行），LLM 容易遗漏关键信息。先转化为结构化数据，每个下游 Agent 只需读取自己负责模块的 JSON。

**输出格式：**
```json
{
  "modules": [
    {
      "module_name": "alu",
      "type": "functional_unit",
      "description": "Arithmetic and logic unit for RV32I operations",
      "ports": [
        {"name": "a", "direction": "input", "width": 32, "description": "Operand A"},
        {"name": "b", "direction": "input", "width": 32, "description": "Operand B"},
        {"name": "op", "direction": "input", "width": 4, "description": "Operation code"},
        {"name": "result", "direction": "output", "width": 32, "description": "ALU result"},
        {"name": "zero", "direction": "output", "width": 1, "description": "Zero flag"}
      ],
      "functionality": "...",
      "dependencies": []
    }
    // ... 其余 14 个模块
  ]
}
```

**关键设计点：** 端口描述中 `width: 1` 表示单比特信号，`width: 32` 表示 32 位总线。所有方向（input/output）、位宽、用途都明确标注——这是下游 Agent 正确生成代码的前提。

### 2.2 RTL Designer — RTL 设计工程师

**角色定义：**
- Role：Senior RTL Design Engineer
- Backstory：专攻 RISC-V 微架构的资深工程师，实现了数十个处理器核心

**核心任务：** 根据模块规格生成可综合的 Verilog 代码。

**这是整个系统调用最频繁的 Agent**——每个模块至少调用一次，加上修复重试可达 3-5 次。

**Prompt 中的 CRITICAL RULES（关键规则）：**

```
CRITICAL RULES — VIOLATION WILL CAUSE COMPILATION FAILURE:
- This file MUST contain EXACTLY ONE module definition. NEVER embed other modules.
- Use `output wire` for signals driven by `assign`, `output reg` for signals 
  driven in `always` blocks. NEVER use `assign` on a `reg`.
- Extract bit-selects like `signal[3:0]` into a `wire` with `assign` before 
  using them inside `always` blocks.
- If this module instantiates dependency modules, just instantiate them by 
  name — do NOT redefine them.
- Every `module` MUST end with exactly one `endmodule`.
```

为什么需要这些 CRITICAL RULES？因为我们从反复的失败中总结出：**LLM 在 Verilog 语法细节上会反复犯同样的错误**。这些规则不是"最佳实践"建议，而是"违反即编译失败"的硬约束。

**依赖上下文注入：** 生成 `id_stage` 时，会自动收集已生成的 `control_unit`、`imm_gen`、`reg_file` 的端口列表作为上下文。例如：

```
DEPENDENCY CONTEXT:
--- control_unit (dependency) ---
module control_unit (
    input  [31:0] instr,
    output reg    alu_src,
    output reg [3:0] alu_op,
    ...
);
```

这样 Agent 在实例化依赖模块时，知道准确的端口名，而不是凭记忆"猜测"。

### 2.3 Code Reviewer — 代码审查员

**角色定义：**
- Role：RTL Code Reviewer
- Backstory：审查了数千个 RTL 设计的代码审查专家

**核心任务：** 审查生成的 RTL 代码，输出结构化的审查反馈。

**检查清单（10 项）：**

1. 端口连接错误——输出信号未连接或连接到错误的内部信号
2. Latch 推断——组合逻辑块中缺少 else/default 分支
3. 阻塞/非阻塞赋值错误——sequential 块中用 `=` 或 combinational 块中用 `<=`
4. 复位处理缺失——rst_n 信号未在 always 块中检查
5. case 语句不完备——缺少 default 分支
6. 位宽不匹配——赋值两侧位宽不一致
7. 默认值缺失——信号在某些分支未赋值
8. 多驱动——同一信号在多个 always 块中被赋值
9. 综合兼容性问题——使用了不可综合的语法（如 `$display` 在 RTL 中）
10. 规格符合性——生成的代码是否与 Spec 中的端口列表一致

**输出格式：**
```json
{
  "module_name": "id_stage",
  "passed": false,
  "issues": [
    {
      "severity": "critical",
      "line": 99,
      "description": "JALR PC 目标地址计算错误：缺少 immediate 加法",
      "fix_suggestion": "改为: id_pc_target = (rf_rs1_data + gen_imm) & 32'hFFFFFFFE;"
    }
  ],
  "summary": "id_stage 模块有 8 个问题需要关注。最关键的是 JALR PC 计算错误..."
}
```

**审查与修复的闭环：** 如果审查发现 `critical` 级别问题，系统会自动触发 `rtl_fix_task`，将审查反馈发回 RTL Designer 进行修复。

### 2.4 Testbench Generator — 验证工程师

**角色定义：**
- Role：Verification Engineer
- Backstory：精通 UVM 和定向测试的验证工程师

**核心任务：** 为每个模块生成**自检查**验证平台。

**Testbench 要求：**
- 包含 `$dumpfile("{module_name}_tb.vcd")` 和 `$dumpvars` 用于 VCD 波形导出
- 生成时钟信号（如果模块有时钟输入）
- 施加复位序列
- 多种测试用例（正常操作 + 边界条件）
- 自检查机制：比较输出与期望值，输出 `TEST PASSED` 或 `TEST FAILED`
- 使用 `$display` 打印测试进度
- 设置 `timescale 1ns/1ps

**为什么是"自检查"而不是手动检查波形？** 15 个模块 × N 个测试用例 = 大量验证工作。只有自检查 testbench 才能在无人干预的情况下自动判断对错。

### 2.5 Integration Architect — 集成架构师

**角色定义：**
- Role：SoC Integration Architect
- Backstory：擅长从独立模块组装复杂处理器核心的集成专家

**核心任务：** 生成顶层 `rv32i_core` 模块，正确实例化并连接全部 14 个子模块。

**任务复杂度：** 这是整个流水线中**上下文最长、最容易出错**的任务。Agent 需要：
- 知道所有 14 个子模块的精确端口名
- 在顶层声明数百个内部连接线
- 正确连接 IMEM 和 DMEM 外部接口
- 连接流水线寄存器（4 组）、功能单元（5 个）、Hazard 控制信号
- 确保所有信号方向正确（input/output 不反接）

---

## 第三部分：任务编排策略

### 3.1 九阶段流水线

```
Phase 1  Spec Analysis        解析Markdown → 15个JSON模块规格
Phase 2  RTL Generation ×15   逐模块生成Verilog（含即时语法检查+修复）
Phase 3  Code Review ×15      审查每个模块的RTL质量
Phase 4  Testbench ×14        生成14个自检查验证平台
Phase 5  Integration          生成顶层rv32i_core模块
Phase 6  Compilation          iverilog全量编译（最多3轮反馈修复）
Phase 7  Simulation           vvp仿真 → VCD波形
Phase 8  Synthesis            yosys综合 → 网表+报告
Phase 9  Knowledge Graph      生成SVG/HTML知识图谱
```

**每一阶段的时长估算（实测数据）：**

| 阶段 | LLM 调用次数 | 单次耗时 | 总耗时 |
|------|------------|---------|--------|
| Spec Analysis | 1 | ~3 分钟 | ~3 分钟 |
| RTL Generation ×15 | 15-30 | ~1-2 分钟 | ~30-60 分钟 |
| Code Review ×15 | 15 | ~1 分钟 | ~15 分钟 |
| Testbench ×14 | 14 | ~2-3 分钟 | ~40 分钟 |
| Integration | 1 | ~5 分钟 | ~5 分钟 |
| Compilation | 0-3 | — | ~10 秒 |
| Simulation | 0 | — | ~5 秒 |
| Synthesis | 0 | — | ~20 秒 |
| Knowledge Graph | 0 | — | ~1 秒 |
| **总计** | **~50** | — | **~2 小时** |

### 3.2 层次化反馈控制回路

这是本项目最核心的设计理念：**LLM 容易出错，所以在 LLM 的每一步之后都插入确定性检查**。

**第一层：即时语法检查（每个模块生成后）**

```
RTL Designer 生成代码
     │
     ▼
iverilog -g2012 -tnull module.v dep1.v dep2.v
     │
     ├── 通过 ──→ 进入 Code Review
     │
     └── 失败 ──→ syntax_fix_task (带错误信息)
                     │
                     ▼
                LLM 修复代码
                     │
                     ▼
               iverilog 重检
                     │
                     ├── 通过 ──→ 进入 Code Review
                     └── 失败 ──→ 重试(最多3次)
```

**第二层：编译反馈回路（全量编译阶段）**

```
全量 iverilog 编译
     │
     ├── 通过 ──→ 进入仿真阶段
     │
     └── 失败 ──→ parse_errors_by_module()
                     │   将错误按模块分组
                     ▼
                 逐个模块 compile_fix_task
                     │   带全部错误信息作为上下文
                     ▼
                 重编译 (最多3轮)
```

**第三层：代码审查（逻辑级验证）**

审查关注功能逻辑而非语法——JALR 计算是否正确、case 是否完备、复位是否处理。

### 3.3 模块依赖顺序

模块按**从叶子到根的拓扑顺序**生成，确保依赖模块先生成：

```
第1批(无依赖):     alu, imm_gen, control_unit, reg_file,
                   if_id_reg, id_ex_reg, ex_mem_reg, mem_wb_reg,
                   hazard_unit
第2批(轻度依赖):   if_stage, mem_stage
第3批(中度依赖):   id_stage, ex_stage, wb_stage
第4批(全量依赖):   rv32i_core
```

这样每生成一个模块时，它的所有依赖模块都已经有 RTL 代码可供语法检查使用。

### 3.4 断点续传

整个流水线需要约 50 次 LLM API 调用，每次 1-5 分钟，总计约 2 小时。中途可能因为网络、API 限流等原因中断。

CheckpointManager 将流水线状态持久化到 `pipeline_state.json`：

```json
{
  "completed_modules": ["alu", "imm_gen", "control_unit", ...],
  "failed_modules": [],
  "retry_counts": {"control_unit": 2},
  "module_details": {
    "alu": {"code_length": 841, "hash": "06d1f85c184fad05", "completed_at": "..."}
  },
  "compilation": {"status": "pending", "timestamp": null},
  "simulation": {"status": "pending", "timestamp": null},
  "synthesis": {"status": "pending", "timestamp": null}
}
```

**恢复机制：**

```
python main.py --resume

→ 读取 checkpoint
→ 已完成模块: alu, imm_gen, control_unit (跳过)
→ 待生成模块: reg_file, if_id_reg, ... (继续)
```

每个模块生成成功后**立即写盘**，不会因为后续模块失败而丢失已完成的工作。

---

## 第四部分：关键技术实现

### 4.1 鲁棒的 LLM 输出解析

LLM 输出格式不可预测——可能包裹在 Markdown 代码块中、可能带额外解释文字、JSON 可能格式错误。

`json_parser.py` 实现了**四级后备策略**：

```
策略1: code_block提取    匹配 ```json ... ``` 或 ```verilog ... ```
    ↓ 失败
策略2: json_block提取    从第一个 { 开始，逐字符计数括号深度
    ↓ 失败                   (正确处理字符串内的转义和括号)
策略3: brace提取         找平衡的 { } 对
    ↓ 失败
策略4: 逐行尝试          每行尝试 json.loads()
    ↓ 失败
兜底: 返回原始文本 + 错误信息
```

对于 Verilog 代码提取，额外逻辑：
- 优先匹配 \`\`\`verilog 代码块
- 若无代码块，匹配从 `module xxx` 到 `endmodule` 的所有内容
- 验证提取的代码是否包含预期的模块名

### 4.2 Fresh LLM 实例机制

**问题：** CrewAI 的 Agent 对象在复用时会积累内部状态。LiteLLM 底层的 httpx 连接池在连续快速调用时会发生连接状态异常，导致 MiniMax/DeepSeek API 返回 `invalid message role: system (2013)` 错误。

**现象：** 第一个模块（alu）生成成功，但从第二个模块开始全部失败，错误完全相同的 `system role` 拒绝。

**解决方案：**

```python
def _create_fresh_llm(self):
    """每次调用都创建全新的 LLM 实例"""
    return create_llm(
        model="deepseek-v4-pro",
        temperature=0.7,
        max_tokens=128000,
        timeout=3600,
    )

def _create_fresh_agents(self):
    """每次调用都创建全新的 Agent 实例"""
    return get_all_agents(self._create_fresh_llm())
```

配合模块间延迟（5 秒）和指数退避重试（5s→10s→20s），彻底解决了复用导致的状态污染问题。

### 4.3 知识图谱可视化

`KnowledgeGraphGenerator` 生成纯 SVG 的 HTML 知识图谱，直观展示：

- **流水线数据流**：if_stage → if_id_reg → id_stage → id_ex_reg → ex_stage → ex_mem_reg → mem_stage → mem_wb_reg → wb_stage
- **功能单元依赖**：id_stage 使用 control_unit（译码）、imm_gen（立即数）、reg_file（读寄存器）
- **Hazard 控制**：hazard_unit 向 IF/ID/EX 阶段输出 stall/flush/forwarding 信号
- **顶层封装**：rv32i_core 以红色节点居中，虚线连接所有 14 个子模块
- **指令集分类**：底部表格列出 RV32I 全部 37 条指令的 R/I/S/B/U/J 六类分组
- **生成状态**：绿色边框=已完成，红色=失败，灰色=待处理

---

## 第五部分：Spec 要做到什么程度？

这是整个系统的**成败前提**。经过反复实验，我们总结了 Specification 质量的评价体系。

### 5.1 Spec 完整度评分表

| 要素 | 必要性 | 缺失后果 | 本 Spec 是否包含 |
|------|--------|---------|:--:|
| **精确的端口列表**（名称+方向+位宽） | ★★★★★ | 端口名/位宽不匹配→编译失败 | ✅ |
| **模块功能的行为级描述** | ★★★★★ | LLM 自由发挥→逻辑错误 | ✅ |
| **ALU 操作码编码表** | ★★★★ | opcode 与 ALU 不匹配→计算结果错误 | ✅ |
| **控制信号真值表**（opcode→control） | ★★★★ | 译码错误→整个流水线异常 | ✅ |
| **复位行为定义**（同步/异步、初值） | ★★★★ | 复位后状态不确定 | ✅ |
| **指令格式的精确位域** | ★★★ | 立即数提取错误→地址计算错误 | ✅ |
| **Hazard 转发路径**（从哪转发到哪） | ★★★ | 数据冒险处理错误 | ✅ |
| **流水线冲刷条件** | ★★★ | 分支/跳转后执行错误指令 | ✅ |
| **时序图**（波形示意图） | ★★ | 时序理解偏差 | ❌ |
| **异常处理**（非法指令行为） | ★★ | 异常处理缺失 | 部分 |

### 5.2 Spec 质量的临界点

当 Spec 信息不足时，LLM 有三大"自由发挥"模式：

**模式 1：端口名猜谜**

```
问题: Spec 说 "register file write data"，没有给端口名
LLM 生成的端口名: rf_wdata, wb_wdata, wr_data, reg_wdata, ...
顶层集成时: 端口名不匹配 → 编译失败
```

**模式 2：控制信号编码自创**

```
问题: Spec 说 "ALU should support ADD/SUB/AND/OR/XOR"
LLM 自己编编码: ADD=4'b0000, SUB=4'b0001, AND=4'b0010, ...
控制单元的编码: ADD=4'b0000, SUB=4'b1000, AND=4'b1010, ...
两组编码不一致 → ALU 算错 → 仿真结果错误 (但编译不会报错!)
```

这是**最隐蔽的 bug**——编译通过，仿真也能跑，但计算结果全是错的。

**模式 3：时序逻辑当组合逻辑写**

```
问题: Spec 没有说明哪级流水线做分支判断
LLM 可能在 EX 阶段用组合逻辑算 branch_taken
也可能在 ID 阶段提前算
两者都"对"，但无法同时存在
```

**经验法则：如果一个人拿着 Spec 能独立写出正确代码，LLM 才能。如果人类需要"开会讨论"才能决定的细节，LLM 一定猜错。**

### 5.3 本项目的 Spec 质量评估

`RISCV_Core_Spec.md`（547 行，约 17848 字符）达到**良好**水平：

**优点：**
- 每个模块都有完整的端口定义（名称、方向、位宽、用途注释）
- ALU 有 10 种操作码的明确定义（`4'd0: ADD, 4'd1: SUB, ...`）
- 立即数生成器有 5 种指令格式的位域拼接规则
- Hazard 单元有完整的信号列表和转发条件
- 顶层有 IMEM 和 DMEM 的接口协议说明

**可改进：**
- 缺少写回阶段的多路选择器逻辑（ALU 结果 vs 内存数据 vs PC+4）
- 缺少具体的流水线冲刷时序（分支预测失败后几个周期冲刷哪几级）
- 缺少 CSR 寄存器的行为定义
- 未提供任何波形示意图

---

## 第六部分：失败案例与解决方案

### 案例 1：wire/reg 赋值错误（最高频，~40% 模块受影响）

**错误现象：**
```
iverilog: alu_src is not a valid l-value in control_unit
```

**原因：** LLM 将端口声明为 `output wire alu_src`，但在 `always @(*)` 块中对它赋值。Verilog 中 `wire` 不能被 `always` 块驱动。

**失败的修复尝试：** 用 LLM 的 `syntax_fix_task` 修复——LLM 往往"修了 A 坏了 B"，把 `wire` 改成 `reg` 但忘记改 `assign`，或者反过来。

**正确方案：** 应该在 Prompt 的 CRITICAL RULES 中明确强调 `output wire` vs `output reg` 的使用规则，并在生成后用 iverilog 立即检查、用**确定性规则**自动修复（不依赖 LLM）。

### 案例 2：内嵌子模块定义（~30% 模块受影响）

**错误现象：**
```
iverilog: 'control_unit' has already been declared in this scope
```

**原因：** `id_stage.v` 文件的 `endmodule` 之后又包含了一个完整的 `control_unit` 模块定义。LLM 在生成 `id_stage` 时，为了"提供完整上下文"，把依赖模块的实现也复制进去了。

**失败的修复尝试：** `compile_fix_task` 修复时只删了一部分，在第三次编译尝试中 `rv32i_core.v` 又内嵌了 `hazard_unit`。

**正确方案：** 用**确定性检测**——扫描文件中 `module` 关键字出现次数，超过 1 次就截断到第一个 `endmodule`。

### 案例 3：集成阶段端口名不一致

**错误现象：**
```
iverilog: port 'mem_rd_addr_out' is not a port of mem_wb_reg_inst
```

**原因：** `mem_stage.v` 的输出端口叫 `mem_rd_addr_out`（带 `_out` 后缀），但 `mem_wb_reg.v` 的输入端口叫 `mem_rd_addr`（无后缀）。集成 Agent 不知道这种不一致，按 `mem_stage` 的输出端口名去连接 `mem_wb_reg`，结果对不上。

**正确方案：** 在集成任务中，向 Agent 提供每个子模块的**真实端口列表**（从实际生成的 RTL 文件中提取），而非依赖 Agent "记住"端口名。

---

## 第七部分：编排策略深度分析

### 7.1 为什么不用一个"全能 Agent"

一个常见的直觉是：用一个强大的 Agent，把所有上下文（Spec + 15 个模块）一次性丢给它，让它输出全部代码。

**为什么不这样做：**

1. **上下文窗口限制**：15 个模块的 Spec + 生成的 RTL 代码 ≈ 50000+ tokens，加上系统提示、对话历史，很容易超出 128K 窗口
2. **注意力衰减**：LLM 对长上下文的中间部分关注度显著下降，后面的模块质量远低于前面的
3. **错误传播**：一个错误会导致全部重来，无法定位具体是哪个模块出问题
4. **无法并行**：无依赖的模块（如 alu、reg_file）完全可以并行生成

### 7.2 Agent 数量的"金发姑娘原则"

5 个 Agent 不是随意定的。少了做不好，多了增加调度开销：

- **< 3 个 Agent**：RTL 生成和代码审查混在同一个 Agent 中 → 自我审查效果差
- **> 7 个 Agent**：增加了不必要的协调开销，Agent 间传递信息的损耗增大
- **5 个 Agent**：每个有清晰的单一职责，信息流清晰

### 7.3 模型能力与任务粒度的关系

模型能力越弱，任务粒度需要越细：

| 模型能力 | 推荐策略 | 单次任务复杂度 |
|---------|---------|-------------|
| GPT-4/Claude 3.5 | 可直接生成复杂模块（如整个 id_stage） | 高 |
| DeepSeek V3/V4 | 需要详细的 CRITICAL RULES + 即时语法检查 | 中 |
| 开源 7B-13B 模型 | 需要进一步拆分（先说端口、再说 always 块、再说 assign） | 低 |

**核心理念：不要让 LLM 做它不擅长的事。语法检查交给编译器，逻辑设计交给 LLM。**

### 7.4 当前方案的局限性

**已经解决的问题：**
- ✅ 15 个模块全部自动生成
- ✅ 全量编译通过（iverilog）
- ✅ 仿真通过生成 VCD 波形
- ✅ 综合通过产生 285 单元网表

**尚未解决的问题：**

1. **功能正确性未验证**：编译和综合通过 ≠ 处理器能正确执行 RV32I 指令。需要用 RISC-V 官方测试集（riscv-tests）做指令级验证。

2. **语法修复仍依赖 LLM**：`syntax_fix_task` 和 `compile_fix_task` 还是用 LLM 修 LLM 的错，成功率不够高。应改为基于规则的确定性修复。

3. **集成阶段可靠性不足**：端口名不一致、信号遗漏等问题在顶层集成时集中爆发，当前反馈回路（3 次重试）不能保证解决。

4. **Token 消耗大**：每次任务都包含完整的 CRITICAL RULES 和 Spec 上下文，平均每次调用消耗 5000-15000 tokens。

---

## 第八部分：总结

### 核心方法论

**"LLM 做设计，编译器做检查，规则做修复"**

这是本项目最核心的方法论贡献。三者分工明确：
- **LLM** 做它擅长的事：从自然语言规格中理解设计意图，生成代码框架
- **编译器（iverilog/yosys）** 做它擅长的事：精确的语法和综合检查
- **确定性规则** 做最简单的修复：wire→reg 转换、内嵌模块检测（不应委托给 LLM）

### 关键数据

| 指标 | 数值 |
|------|------|
| Python 代码量 | 4,214 行 |
| Spec 文档 | 547 行 Markdown |
| Agent 数量 | 5 个 |
| 任务模板数 | 8 个 |
| 生成的 Verilog 模块 | 15 个 |
| 流水线阶段数 | 9 个 |
| 单次完整运行耗时 | ~2 小时 |
| LLM API 调用次数 | ~50 次 |
| 最终综合结果 | 285 个逻辑单元（35 DFF + 60 MUX + 89 比较器 + ...） |

### 给实践者的建议

1. **Spec 是一切的基石**。花 60% 的时间打磨 Spec，LLM 只需要 40% 的时间生成代码。端口名不确定？写下来。操作码编码没定义？写下来。不确定信号是 input 还是 output？写下来。

2. **LLM 不可信，编译器才可信**。永远不要在"LLM 说代码是对的"时就进入下一阶段。必须经过 `iverilog` 的编译验证。

3. **失败了就重试，但要聪明地重试**。告诉 LLM 具体的错误信息（文件、行号、错误类型），比让它"重新生成一次"有效得多。

4. **按依赖顺序生成，保存中间产物**。断点续传不是"锦上添花"，对于 2 小时的长流程它是必需品。

5. **从失败中提取规则**。每个 CRITICAL RULE 背后都是一次或多次编译失败。把这些规则写进 Prompt，下次就不会再犯。

---

*项目地址：https://github.com/CVYang/veriGraph*  
*技术栈：CrewAI 1.14 × DeepSeek V4 Pro × LiteLLM × Icarus Verilog × Yosys 0.35*  
*代码规模：4,214 行 Python + 547 行 Spec Markdown*

---

**参考文献**

[1] CVYang. *VeriGraph: A Multi-Agent Framework for Automated RTL Generation.* arXiv:2604.14550, 2026.  
　　https://arxiv.org/abs/2604.14550

[2] CrewAI. *Multi-Agent Orchestration Framework.* https://github.com/crewAIInc/crewAI

[3] Wolf, C. *Yosys Open Synthesis Suite.* https://github.com/YosysHQ/yosys

[4] Williams, S. *Icarus Verilog.* https://github.com/steveicarus/iverilog
