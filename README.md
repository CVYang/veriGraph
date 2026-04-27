# VeriGraphi - Multi-Agent Framework for Hierarchical RTL Generation

基于论文 [arXiv:2604.14550](https://arxiv.org/abs/2604.14550) 实现的 RISC-V 处理器 RTL 生成框架。

## 项目概述

VeriGraphi 使用多 Agent 协作架构，从规格文档（Spec）自动生成可综合的 Verilog RTL 代码。

### 核心架构

```
规格文档 → 架构分析 → 知识图谱 → 渐进式编码 → 验证 → RTL输出
           (Agent)    (HDA)      (Agent)    (Agent)
```

1. **架构分析模块**: 解析规格文档，分解为模块化的实现计划
2. **分层架构模块**: 构建知识图谱（HDA），显式编码模块层级和接口
3. **渐进式编码模块**: 自底向上生成 RTL，包含迭代修正机制
4. **验证模块**: 基于规格生成测试用例，验证功能正确性

## 目录结构

```
verigraphi/
├── src/
│   ├── core/
│   │   └── models.py          # 核心数据模型 (HDA, ModuleNode, Edge)
│   ├── agents/
│   │   ├── base.py             # Agent 基类和 LLM 客户端
│   │   ├── architectural_analysis.py  # 架构分析 Agent
│   │   ├── hierarchy_analysis.py      # 知识图谱构建 Agent
│   │   ├── progressive_coding.py       # RTL 生成 Agent
│   │   └── verification.py             # 验证 Agent
│   └── verigraphi.py           # 主 pipeline 编排
├── config/
│   └── config.yaml             # 配置文件
├── spec/
│   └── RISCV_Core_Spec.md      # RISC-V 核规格文档
├── output/                     # 生成结果目录
├── run.py                      # 快速启动脚本
├── cli.py                      # CLI 工具
└── requirements.txt
```

## 安装

```bash
pip install -r requirements.txt
```

可选工具（用于验证）：
- **Icarus Verilog**: `apt install iverilog` 或 `brew install icarus-verilog`
- **Yosys**: `apt install yosys` 或 `brew install yosys`

## 使用方法

### 方法 1: 快速启动

```bash
export MINIMAX_API_KEY="your-api-key"
python run.py
```

### 方法 2: CLI 工具

```bash
# 完整 pipeline
python cli.py full --spec spec/RISCV_Core_Spec.md --key YOUR_API_KEY

# 仅架构分析
python cli.py analyze --spec spec/RISCV_Core_Spec.md --key YOUR_API_KEY

# 仅生成 RTL（需要先完成分析）
python cli.py generate --key YOUR_API_KEY
```

### 方法 3: 作为模块使用

```python
from src.verigraphi import VeriGraphiPipeline

pipeline = VeriGraphiPipeline(
    api_key="your-api-key",
    model="MiniMax-Text-01",
    provider="minimax"
)

results = pipeline.run(
    spec_path="spec/RISCV_Core_Spec.md",
    output_dir="./output"
)
```

## 支持的 LLM Provider

- **MiniMax** (默认): 使用 `MiniMax-Text-01` 模型
- **OpenAI**: GPT-4o, GPT-4o-mini 等
- **Anthropic**: Claude 3.5 等

配置示例：

```python
# MiniMax
pipeline = VeriGraphiPipeline(api_key="...", provider="minimax", model="MiniMax-Text-01")

# OpenAI
pipeline = VeriGraphiPipeline(api_key="...", provider="openai", model="gpt-4o")

# Anthropic
pipeline = VeriGraphiPipeline(api_key="...", provider="anthropic", model="claude-3-5-sonnet")
```

## 输出说明

Pipeline 完成后，`output/` 目录包含：

```
output/
├── implementation_plan.json   # 实现计划
├── kg/
│   └── hda.json              # 知识图谱
├── rtl/
│   ├── registerfile.v       # 生成的 RTL 模块
│   ├── alu.v
│   └── ...
└── tests/
    └── ...                   # 验证测试
```

## 论文对照

本实现严格遵循 VeriGraphi 论文架构：

| 论文章节 | 实现模块 |
|---------|---------|
| III-B | `architectural_analysis.py` - Summarizer, Decomposer, Specifier, Auditor Agents |
| III-C | `hierarchy_analysis.py` - KG Builder Agent, HDA Construction |
| III-D | `progressive_coding.py` - Pseudo Coder, Coder, Syntax Checker, Prompt Enhancer, Assembler |
| III-E | `verification.py` - Verifier Agent, Synthesis Validation |

## 限制

- 当前版本针对 RV32I 基础指令集
- 完整验证需要商用仿真器（可选）
- 知识图谱连接推断使用启发式方法

## License

MIT