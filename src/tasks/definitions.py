"""
CrewAI Task definitions for VeriGraph multi-agent RTL generation system.

Tasks are designed to be granular and self-contained to avoid context overflow.
Each task produces structured output that is saved to disk immediately.
"""

from crewai import Task
from typing import Optional


# ============================================================
# Spec Analysis Tasks
# ============================================================

def create_spec_analysis_task(agent, spec_text: str):
    """Task: Parse the full RV32I specification into structured module data."""
    return Task(
        description=f"""
Analyze the following RV32I core specification and extract structured information for ALL 15 modules.

For EACH module, extract:
1. module_name: exact name (e.g., "alu", "if_stage")
2. type: "pipeline_stage", "functional_unit", "pipeline_register", "control", or "top"
3. description: one-sentence description of the module's purpose
4. ports: list of all ports with:
   - name: port name
   - direction: "input", "output", or "inout"
   - width: bit width (e.g., 1, 32, [31:0])
   - description: what this port does
5. functionality: detailed description of the module's behavior
6. dependencies: list of module names this module depends on

SPECIFICATION:
{spec_text}

IMPORTANT: Return a JSON object with a single key "modules" containing an array of 15 module objects.
Format: {{"modules": [{{"module_name": "...", "type": "...", ...}}, ...]}}
Make sure to include ALL 15 modules from the specification.
""",
        expected_output="JSON with structured module specifications for all 15 modules",
        agent=agent,
    )


# ============================================================
# RTL Generation Tasks — One per module
# ============================================================

def create_rtl_generation_task(agent, module_spec: dict, dependencies_context: str = ""):
    """
    Task: Generate Verilog RTL for a single module.

    Args:
        module_spec: Dict with module specification (from spec_analysis)
        dependencies_context: Optional context about dependent modules
    """
    module_name = module_spec.get("module_name", "unknown")
    module_type = module_spec.get("type", "unknown")
    description = module_spec.get("description", "")
    ports = module_spec.get("ports", [])
    functionality = module_spec.get("functionality", "")

    # Build ports section
    ports_text = ""
    for p in ports:
        direction = p.get("direction", "input")
        name = p.get("name", "")
        width = p.get("width", 1)
        desc = p.get("description", "")
        if isinstance(width, int) and width > 1:
            ports_text += f"    {direction} logic [{width-1}:0] {name}  // {desc}\n"
        else:
            ports_text += f"    {direction} logic {name}  // {desc}\n"

    deps_info = f"\nDEPENDENCY CONTEXT:\n{dependencies_context}" if dependencies_context else ""

    return Task(
        description=f"""
Generate synthesizable SystemVerilog RTL code for the following module.

MODULE: {module_name}
TYPE: {module_type}
DESCRIPTION: {description}

PORTS:
{ports_text}

FUNCTIONALITY:
{functionality}
{deps_info}

REQUIREMENTS:
1. Use standard Verilog-2001 syntax (wire/reg, not logic for ports)
2. Non-blocking assignments (<=) in always_ff/sequential blocks
3. Blocking assignments (=) in always @(*) / combinational blocks
4. Use `always @(*)` instead of `always_comb` (for iverilog compatibility)
5. Handle reset properly (rst_n is active-low)
6. Include all ports exactly as specified
7. Add proper default values in all case/if branches to avoid latch inference
8. Use consistent naming conventions (snake_case)

CRITICAL RULES — VIOLATION WILL CAUSE COMPILATION FAILURE:
- This file MUST contain EXACTLY ONE module definition. NEVER embed other modules.
- Use `output wire` for signals driven by `assign` statements, `output reg` for signals driven in `always` blocks. NEVER use `assign` on a `reg`.
- Extract bit-selects like `signal[3:0]` into a `wire` with `assign` before using them inside `always` blocks.
- If this module instantiates dependency modules, just instantiate them by name — do NOT redefine them.
- Every `module` MUST end with exactly one `endmodule`.

IMPORTANT: Return ONLY the Verilog code inside ```verilog ... ``` code block.
Do NOT include extra explanation. Just the code.
""",
        expected_output=f"Complete Verilog RTL code for module {module_name}",
        agent=agent,
    )


# ============================================================
# Code Review Tasks
# ============================================================

def create_code_review_task(agent, module_name: str, rtl_code: str, module_spec: dict):
    """Task: Review generated RTL code for correctness."""
    return Task(
        description=f"""
Review the following Verilog RTL code for module '{module_name}'.

MODULE SPECIFICATION:
- Type: {module_spec.get('type', 'unknown')}
- Description: {module_spec.get('description', '')}
- Key functionality: {module_spec.get('functionality', '')}

RTL CODE TO REVIEW:
```verilog
{rtl_code}
```

Check for:
1. Missing or incorrect port connections
2. Latch inference (missing else/default in combinational blocks)
3. Incorrect use of blocking vs non-blocking assignments
4. Missing reset handling
5. Incomplete case statements
6. Width mismatches
7. Missing default assignments
8. Unintended multiple drivers
9. Synthesis compatibility issues
10. Adherence to the module specification

Return a JSON object with:
{{
    "module_name": "{module_name}",
    "passed": true/false,
    "issues": [
        {{
            "severity": "critical/high/medium/low",
            "line": <line number or null>,
            "description": "issue description",
            "fix_suggestion": "how to fix"
        }}
    ],
    "summary": "brief overall assessment"
}}

IMPORTANT: Return ONLY the JSON. No markdown, no extra text.
""",
        expected_output=f"Code review results in JSON format for module {module_name}",
        agent=agent,
    )


# ============================================================
# Testbench Generation Tasks
# ============================================================

def create_testbench_generation_task(agent, module_name: str, rtl_code: str, module_spec: dict):
    """Task: Generate a testbench for a module."""
    return Task(
        description=f"""
Generate a comprehensive, self-checking Verilog testbench for module '{module_name}'.

MODULE UNDER TEST: {module_name}
TYPE: {module_spec.get('type', 'unknown')}
DESCRIPTION: {module_spec.get('description', '')}

RTL CODE OF MODULE UNDER TEST:
```verilog
{rtl_code}
```

REQUIREMENTS:
1. Include $dumpfile("{module_name}_tb.vcd") and $dumpvars for waveform generation
2. Generate a clock signal (if module has clk input)
3. Apply reset at the beginning
4. Test normal operation with multiple test cases
5. Test edge cases
6. Self-checking: compare outputs with expected values
7. Print "TEST PASSED" or "TEST FAILED" at the end
8. Display test progress with $display statements
9. Use timescale `timescale 1ns/1ps
10. Module name: tb_{module_name}

IMPORTANT: Return ONLY the Verilog testbench code inside ```verilog ... ``` code block.
""",
        expected_output=f"Complete Verilog testbench for module {module_name}",
        agent=agent,
    )


# ============================================================
# Integration Tasks
# ============================================================

def create_integration_task(agent, all_module_rtl: dict, module_specs: dict):
    """
    Task: Create the top-level rv32i_core wrapper that instantiates all submodules.

    Args:
        all_module_rtl: Dict mapping module_name -> generated RTL code
        module_specs: Dict mapping module_name -> module specification
    """
    # Build context about available submodules and their ports
    submodules_info = ""
    for name, rtl in sorted(all_module_rtl.items()):
        if name == "rv32i_core":
            continue
        # Extract module header (first ~30 lines)
        lines = rtl.strip().split("\n")
        header = "\n".join(lines[:min(30, len(lines))])
        submodules_info += f"\n{'='*60}\nModule: {name}\n{header}\n"

    return Task(
        description=f"""
Create the top-level 'rv32i_core' wrapper module that instantiates and connects ALL submodules.

The rv32i_core is the top-level wrapper with these ports:
- input clk, input rst_n
- IMEM interface: output imem_addr[31:0], input imem_rdata[31:0], output imem_req
- DMEM interface: output dmem_addr[31:0], output dmem_wdata[31:0], input dmem_rdata[31:0], output dmem_req, output dmem_we, output dmem_be[3:0]

SUB-MODULES TO INSTANTIATE:
1. if_stage - Instruction fetch
2. id_stage - Instruction decode
3. ex_stage - Execute
4. mem_stage - Memory access
5. wb_stage - Write-back
6. reg_file - Register file (32x32)
7. alu - Arithmetic logic unit
8. imm_gen - Immediate generator
9. control_unit - Instruction decoder
10. hazard_unit - Hazard detection & forwarding
11. if_id_reg - IF/ID pipeline register
12. id_ex_reg - ID/EX pipeline register
13. ex_mem_reg - EX/MEM pipeline register
14. mem_wb_reg - MEM/WB pipeline register

CONNECTION REQUIREMENTS:
- Connect all pipeline stages through pipeline registers
- Connect functional units (alu, imm_gen, control_unit) to appropriate stages
- Connect reg_file to id_stage (read) and wb_stage (write)
- Connect hazard_unit to IF, ID, EX stages for stall/flush/forwarding
- Connect IMEM interface to if_stage
- Connect DMEM interface to mem_stage
- Wire all control signals correctly

SUB-MODULE PORT DEFINITIONS (for reference):
{submodules_info}

REQUIREMENTS:
1. Use standard Verilog-2001 syntax
2. Correctly instantiate all 14 submodules
3. Connect all ports with properly named internal wires
4. Add comments for each instantiation
5. Use consistent wire naming (format: signal_name)
6. Include proper wire/reg declarations for all internal signals
7. The code must be synthesizable

IMPORTANT: Return ONLY the Verilog code inside ```verilog ... ``` code block.
""",
        expected_output="Complete top-level rv32i_core Verilog code with all submodule instantiations",
        agent=agent,
    )


# ============================================================
# RTL Fix Tasks (for code review fixes)
# ============================================================

def create_rtl_fix_task(agent, module_name: str, original_code: str, review_feedback: dict):
    """Task: Fix RTL code based on code review feedback."""
    issues = review_feedback.get("issues", [])
    issues_text = "\n".join([
        f"- [{i.get('severity', '?')}] {i.get('description', '')} -> {i.get('fix_suggestion', '')}"
        for i in issues
    ])

    return Task(
        description=f"""
Fix the following Verilog RTL code for module '{module_name}' based on code review feedback.

CODE REVIEW ISSUES FOUND:
{issues_text}

ORIGINAL CODE:
```verilog
{original_code}
```

Apply all the suggested fixes and return the corrected Verilog code.

IMPORTANT: Return ONLY the fixed Verilog code inside ```verilog ... ``` code block.
""",
        expected_output=f"Fixed Verilog RTL code for module {module_name}",
        agent=agent,
    )


def create_syntax_fix_task(agent, module_name: str, original_code: str, errors: list):
    errors_text = "\n".join([f"  - {e}" for e in errors[:10]])

    return Task(
        description=f"""
Fix the Verilog compilation errors in module '{module_name}'.

COMPILATION ERRORS FROM IVERILOG:
{errors_text}

CURRENT CODE:
```verilog
{original_code}
```

ABSOLUTE RULES (check every line):
1. ONE module per file. If this file has multiple `module ... endmodule` blocks, REMOVE all but the `{module_name}` module.
2. `output reg` ports must NEVER be driven by `assign`. Use `output wire` if you use `assign`.
3. `wire` signals must NEVER be assigned inside `always` blocks. Use `reg` instead.
4. All signals must be declared (wire or reg) before use.
5. Bit-selects like `signal[3:0]` inside `always @(*)` blocks are NOT supported. Extract to a `wire` with `assign` outside the always block.
6. Every instantiated module must be connected with its EXACT port names (check dependency files).

Return ONLY the fixed Verilog code inside ```verilog ... ``` code block.
""",
        expected_output=f"Fixed Verilog RTL code for module {module_name}",
        agent=agent,
    )


def create_compile_fix_task(agent, module_name: str, original_code: str, all_errors: list):
    """
    Task: Fix compilation errors detected during full project compilation.
    Includes context about ALL module errors so the agent can reason about cross-module issues.
    """
    errors_text = "\n".join([f"  - {e}" for e in all_errors[:15]])

    return Task(
        description=f"""
Fix compilation errors for module '{module_name}'.

ALL COMPILATION ERRORS ACROSS THE PROJECT:
{errors_text}

CURRENT CODE FOR '{module_name}':
```verilog
{original_code}
```

CRITICAL RULES:
1. NEVER define another module inside this file. Each file must contain EXACTLY ONE module.
2. If this module instantiates other modules, they must exist as SEPARATE files — do NOT copy their definitions here.
3. `output reg` signals MUST NOT be driven by `assign` — use `output wire` or move to an `always` block.
4. Ensure all port names match EXACTLY what other modules expect.

Return ONLY the fixed Verilog code inside ```verilog ... ``` code block.
""",
        expected_output=f"Fixed Verilog RTL code for module {module_name}",
        agent=agent,
    )
