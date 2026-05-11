# VeriGraph

> Multi-Agent RTL Generation Framework — From Specification to Netlist

VeriGraph 是一个基于 CrewAI 多智能体框架的 RTL 代码自动生成系统。输入一份 RISC-V 处理器规格文档（Markdown），五个 AI Agent 协作，自动生成完整的、可综合的 Verilog RTL 代码，并通过 iverilog 编译、vvp 仿真、yosys 综合，最终产出门级网表和综合报告。

本项目是论文 *"VeriGraph: A Multi-Agent Framework for Automated RTL Generation"*（[arXiv:2604.14550](https://arxiv.org/abs/2604.14550)）的工程实现。

---

## Architecture

```
spec/RISCV_Core_Spec.md (547行 Markdown)
           │
           ▼
┌─────────────────────────────────────┐
│        CrewAI Multi-Agent 层         │
│                                     │
│  Spec Analyst  →  RTL Designer      │
│       ↓               ↓             │
│  Code Reviewer ←  Testbench Gen     │
│       ↓                             │
│  Integration Architect               │
└─────────────────┬───────────────────┘
                  │
                  ▼
┌─────────────────────────────────────┐
│           EDA 工具链层               │
│                                     │
│  iverilog 编译 → vvp 仿真 → yosys   │
│                                     │
│  产物: .v 源码 + .vcd 波形 + .v 网表 │
└─────────────────────────────────────┘
```

**5 Agents / 8 Tasks / 9 Pipeline Phases / 15 Verilog Modules**

| Agent | 职责 |
|-------|------|
| **Spec Analyst** | 解析 Markdown 规格 → 15 个结构化 JSON |
| **RTL Designer** | 逐模块生成可综合 Verilog 代码 |
| **Code Reviewer** | 审查代码正确性，输出结构化反馈 |
| **Testbench Generator** | 生成自检查验证平台 + VCD 波形导出 |
| **Integration Architect** | 组装顶层 rv32i_core 实例化全部子模块 |

**目标产物：RV32I 单发射五级流水线核心**

| 类别 | 模块 | 数量 |
|------|------|:--:|
| 流水线级 | if_stage, id_stage, ex_stage, mem_stage, wb_stage | 5 |
| 功能单元 | alu, reg_file, imm_gen, control_unit, hazard_unit | 5 |
| 流水线寄存器 | if_id_reg, id_ex_reg, ex_mem_reg, mem_wb_reg | 4 |
| 顶层封装 | rv32i_core | 1 |

---

## Quick Start

### Prerequisites

- Python 3.10+
- Icarus Verilog (iverilog + vvp)
- Yosys (可选，用于综合)

Linux 一键安装 EDA 工具：

```bash
# 使用 oss-cad-suite (推荐)
wget https://github.com/YosysHQ/oss-cad-suite-build/releases/latest/download/oss-cad-suite-linux-x64.tgz
tar xzf oss-cad-suite-linux-x64.tgz
export PATH="$PATH:$(pwd)/oss-cad-suite/bin"
```

### Installation

```bash
git clone https://github.com/CVYang/veriGraph.git
cd veriGraph

pip install -r requirements.txt
```

### Configuration

设置 LLM API Key：

```bash
# DeepSeek (默认配置)
export DEEPSEEK_API_KEY="sk-your-key-here"

# 或 MiniMax
export MINIMAX_API_KEY="sk-your-key-here"
```

编辑 `config/config.yaml` 修改模型和流水线参数：

```yaml
llm:
  provider: DeepSeek          # DeepSeek | MiniMax | OpenAI
  model: deepseek-v4-pro      # 模型名称
  temperature: 0.7
  max_tokens: 128000

agents:
  max_iterations: 3            # 最大重试次数
  retry_delay: 5               # 模块间调用延迟(秒)
```

### Usage

```bash
# 检查环境和工具链
python main.py --check-only

# 运行完整流水线
python main.py

# 断点续传
python main.py --resume

# 跳过综合
python main.py --skip-synthesis

# 生成单个模块
python main.py --module alu
```

---

## Pipeline Phases

| Phase | 名称 | 产物 |
|:-----:|------|------|
| 1 | Spec Analysis | 15 个模块的结构化 JSON |
| 2 | RTL Generation ×15 | 每个模块的 Verilog RTL 代码 |
| 3 | Code Review ×15 | 审查报告 (JSON) |
| 4 | Testbench Generation ×14 | 自检查验证平台 (.v) |
| 5 | Integration | 顶层 rv32i_core 封装 (.v) |
| 6 | Compilation | 编译通过的可执行文件 |
| 7 | Simulation | VCD 波形文件 |
| 8 | Synthesis | 门级网表 + 综合报告 |
| 9 | Knowledge Graph | SVG/HTML 知识图谱 |

---

## Project Structure

```
veriGraph/
├── main.py                      # 主编排器 (1199 行)
├── requirements.txt             # Python 依赖
├── article.md                   # 公众号文章
├── config/
│   └── config.yaml              # 流水线配置文件
├── spec/
│   └── RISCV_Core_Spec.md       # RV32I 处理器规格 (547 行)
├── src/
│   ├── agents/
│   │   └── definitions.py       # 5 个 CrewAI Agent 定义
│   ├── tasks/
│   │   └── definitions.py       # 8 个任务模板
│   ├── utils/
│   │   ├── checkpoint.py        # 断点续传管理
│   │   ├── file_manager.py      # 文件/目录管理 + 模块依赖拓扑
│   │   ├── json_parser.py       # LLM 输出鲁棒解析
│   │   └── logger.py            # 多层次日志系统
│   ├── pipeline/
│   │   └── runner.py            # EDA 工具链封装
│   └── graph/
│       └── generator.py         # SVG/HTML 知识图谱生成
├── modules/                     # 逐模块生成目录 (运行时创建)
│   ├── alu/alu.v               #   (已生成的 RTL 代码)
│   ├── control_unit/control_unit.v
│   └── ...
├── output/                      # 最终产物 (运行时创建)
│   ├── rtl/                     #   全量 RTL 副本
│   ├── tests/                   #   测试平台
│   ├── netlist/                 #   综合网表
│   └── waveforms/               #   VCD 波形
├── logs/                        # 日志 (运行时创建)
│   ├── agents/                  #   每个 Agent 的执行日志
│   ├── intermediate/            #   中间结果快照
│   ├── compilation/             #   编译日志
│   ├── simulation/              #   仿真日志
│   └── synthesis/               #   综合日志
├── checkpoints/                 # 断点续传状态
│   └── pipeline_state.json
└── knowledge_graph/             # 可视化 HTML/SVG
    ├── knowledge_graph.html
    ├── graph.svg
    ├── module_list.html
    └── modules/
```

---

## Key Features

### 多层次反馈控制

```
LLM生成 → iverilog语法检查 → 失败? LLM修复 → 重检 → 通过? 下一步
```

| 检查层 | 时机 | 机制 |
|--------|------|------|
| **即时语法检查** | 每个模块生成后 | `iverilog -tnull` + 依赖文件 |
| **编译反馈回路** | 全量编译时 | 解析错误→按模块修复→重编译(最多3轮) |
| **代码审查** | 每个模块生成后 | LLM 审查 10 类逻辑问题 |

### 断点续传

流水线状态保存到 `checkpoints/pipeline_state.json`。每个模块生成成功后**立即写盘**。
中断后 `python main.py --resume` 从断点恢复，已完成模块自动跳过。

### 鲁棒输出解析

LLM 输出不可预测——`json_parser.py` 实现四级后备策略：
1. Markdown 代码块匹配
2. 平衡括号深度解析（处理字符串转义）
3. 逐行 JSON 尝试
4. 模块名 + `endmodule` 定位

### Fresh LLM 实例

每次 API 调用创建全新 LLM + Agent 实例，避免 CrewAI 内部状态污染。配合模块间 5 秒延迟和指数退避重试。

### 知识图谱

纯 SVG 的 HTML 可视化，展示：
- 5 级流水线数据流（彩色节点 + 箭头）
- 功能单元依赖关系（虚线 + 标签）
- RV32I 37 条指令分类
- 每个模块的独立详情页（暗色 IDE 主题）

---

## EDA Flow

```bash
# 语法检查 (每个模块生成后)
iverilog -g2012 -tnull module.v dep1.v dep2.v

# 全量编译
iverilog -g2012 -o output/rv32i_core_sim -I modules/ [15个.v文件]

# 仿真 (生成 VCD 波形)
vvp output/simulation
# → output/waveforms/waveform.vcd

# 综合 (生成网表)
yosys -s script.ys
# script.ys 内容:
#   read_verilog -sv [每个.v文件]
#   hierarchy -check -top rv32i_core
#   proc; flatten; opt; fsm; opt
#   stat
#   write_verilog -noattr output/netlist/rv32i_core_netlist.v
```

---

## Configuration Reference

### `config/config.yaml`

```yaml
agents:
  max_iterations: 3        # Agent 最大重试次数
  timeout_seconds: 3600    # LLM 调用超时(秒)
  retry_delay: 5           # 模块间延迟(秒), 避免 API 限流

llm:
  provider: DeepSeek       # LLM 提供商
  model: deepseek-v4-pro   # 模型名称
  temperature: 0.7         # 生成温度 (0=确定, 1=随机)
  max_tokens: 128000       # 最大输出 token 数

rtl:
  output_dir: ./output/rtl
  indent: "  "
  line_width: 512

verification:
  test_dir: ./output/tests
  coverage_threshold: 0.9

pipeline:
  enable_verification: true    # 是否启用验证
  enable_syntax_check: true    # 是否启用即时语法检查
  parallel_agents: true        # 是否并行生成无依赖模块
```

---

## Module Dependency Order

模块按**叶子→根**的拓扑顺序生成：

```
第1批(无依赖):       alu, imm_gen, control_unit, reg_file,
                     if_id_reg, id_ex_reg, ex_mem_reg, mem_wb_reg,
                     hazard_unit
第2批(轻度依赖):     if_stage, mem_stage
第3批(中度依赖):     id_stage, ex_stage, wb_stage
第4批(全量依赖):     rv32i_core
```

---

## Troubleshooting

### `litellm.BadRequestError: invalid message role: system (2013)`

**根因：** CrewAI/LiteLLM 复用 Agent 实例时内部状态污染。

**解决：** 系统已内置 Fresh LLM 机制（每次调用创建新实例）。如仍出现，增大 `config.yaml` 中的 `retry_delay`。

### `iverilog: error: Unknown module type`

**根因：** 顶层模块实例化了尚未生成的子模块。

**解决：** 运行 `python main.py --resume` 继续生成剩余模块。模块按依赖顺序生成，顶层最后生成。

### `iverilog: has already been declared in this scope`

**根因：** LLM 在文件中内嵌了依赖模块的完整定义。

**解决：** 系统会自动检测并触发 `compile_fix_task` 修复。检查 `modules/{module}/{module}.v` 文件中 `endmodule` 之后是否还有额外代码。

---

## Results

```
✅ Spec Analysis:      15 模块结构提取完成
✅ RTL Generation:     15/15 模块生成成功
✅ Code Review:        全部模块审查通过
✅ Testbench:          14 个测试平台生成完成
✅ Integration:        顶层 rv32i_core 集成完成
✅ Compilation:        iverilog 编译通过
✅ Simulation:         vvp 仿真通过，VCD 波形已保存
✅ Synthesis:          yosys 综合通过
   ├── Total Cells:    285
   ├── D Flip-Flops:   35
   ├── Multiplexers:   60
   ├── Comparators:    89
   └── Netlist:        output/netlist/rv32i_core_netlist.v
```

---

## License

MIT License

## Citation

If you use VeriGraph in your research, please cite both the paper and this implementation:

```bibtex
@misc{verigraph2026,
  title   = {VeriGraph: A Multi-Agent Framework for Automated RTL Generation},
  author  = {CVYang},
  year    = {2026},
  eprint  = {2604.14550},
  archivePrefix = {arXiv},
  url     = {https://arxiv.org/abs/2604.14550}
}

@software{verigraph_impl,
  title   = {VeriGraph: Multi-Agent RTL Generation Framework (Implementation)},
  author  = {CVYang},
  year    = {2026},
  url     = {https://github.com/CVYang/veriGraph}
}
```
