from typing import Dict, Any, List, Optional
import json
import re
from .base import BaseAgent, LLMClient
from ..core.models import RTLModule, KnowledgeGraph, ModuleNode


class PseudoCoderAgent(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="PseudoCoder",
            role="Pseudo Code Generator",
            goal="Generate algorithmic pseudocode for RTL module implementation",
            backstory="""You are an expert hardware designer who writes clear algorithmic
            pseudocode that captures the essence of RTL implementations without getting
            bogged down in syntax details.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        module_spec = context.get("current_module", {})
        detailed_specs = context.get("detailed_specs", {})
        spec_content = context.get("spec_content", "")

        module_name = module_spec.get("name", "unknown")
        spec = detailed_specs.get(module_name, {})

        prompt = f"""Generate algorithmic pseudocode for the following RISC-V module.

MODULE: {module_name}
SPEC: {json.dumps(spec, indent=2)}

ADDITIONAL CONTEXT FROM SPEC:
{spec_content[:3000]}

The pseudocode should describe:
1. **State Machine**: Complete FSM with states and transitions
2. **Data Flow**: How data moves through the module
3. **Control Logic**: How control signals govern behavior
4. **Interface Handshake**: Valid/ready protocols
5. **Edge Cases**: Error conditions and handling

Use pseudocode syntax like:
- IF/ELSE for conditional logic
- FOR/WHILE for loops (if pipelined)
- CASE for mux selection
- <- for assignments
- => for connections

Keep it algorithmic, not Verilog-specific.
"""
        response = self.think(prompt)
        return {"success": True, "pseudo_code": response, "module_name": module_name}


class CoderAgent(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="Coder",
            role="RTL Code Generator",
            goal="Generate synthesizable Verilog RTL from pseudocode and specifications",
            backstory="""You are a senior RTL design engineer who writes clean, synthesizable
            Verilog/VHDL code. Your code follows best practices, is well-organized,
            and properly handles timing and concurrency.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        module_spec = context.get("current_module", {})
        pseudo_code = context.get("pseudo_code", "")
        spec_content = context.get("spec_content", "")

        module_name = module_spec.get("name", "unknown")
        module_type = module_spec.get("type", "module")

        prompt = f"""Generate synthesizable SystemVerilog RTL code for the following module.

MODULE NAME: {module_name}
MODULE TYPE: {module_type}
SPECIFICATIONS:
{json.dumps(module_spec, indent=2)}

PSEUDOCODE:
{pseudo_code}

ADDITIONAL CONTEXT:
{spec_content[:2000]}

Requirements:
1. Use SystemVerilog (logic, always_ff, always_comb, etc.)
2. Include proper reset handling
3. Use non-blocking assignments (<=) in sequential blocks
4. Use blocking assignments (=) in combinational blocks
5. Include module parameters for configurability
6. Use proper clock crossing if needed
7. Include valid/ready handshakes where appropriate
8. Add synthesis attributes where beneficial

Output format:
```systemverilog
// Module: module_name
// Description: ...
module {module_name} (
    // Clock and reset
    input logic clk,
    input logic rst_n,
    // Other signals...
);
    // Implementation
endmodule
```
"""
        response = self.think(prompt)
        rtl_code = self._extract_rtl(response)
        return {"success": True, "rtl_code": rtl_code, "module_name": module_name}

    def _extract_rtl(self, response: str) -> str:
        match = re.search(r'```systemverilog\s*(.*?)\s*```', response, re.DOTALL)
        if match:
            return match.group(1)
        match = re.search(r'```verilog\s*(.*?)\s*```', response, re.DOTALL)
        if match:
            return match.group(1)
        match = re.search(r'```sv\s*(.*?)\s*```', response, re.DOTALL)
        if match:
            return match.group(1)
        return response


class SyntaxCheckerAgent(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="SyntaxChecker",
            role="RTL Syntax Checker",
            goal="Identify and fix syntax errors in generated RTL code",
            backstory="""You are a meticulous RTL verification engineer who spots syntax
            errors, missing connections, and common mistakes in Verilog/SystemVerilog code.
            You provide specific fixes, not just error descriptions.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        rtl_code = context.get("rtl_code", "")
        module_name = context.get("module_name", "unknown")

        prompt = f"""Check the following SystemVerilog code for syntax errors and issues.

MODULE: {module_name}
CODE:
{rtl_code}

Check for:
1. **Syntax Errors**: Missing semicolons, mismatched parentheses, etc.
2. **Port Errors**: Missing ports, wrong directions
3. **Type Errors**: Using wrong types, implicit conversions
4. **Timing Errors**: Missing @ in always_ff, etc.
5. **Best Practices**: Unused signals, incomplete case statements, etc.

Provide specific line-by-line issues and fixes.
If no errors, respond with: "SYNTAX_OK"

Output format (JSON):
{{
    "syntax_ok": true/false,
    "errors": [
        {{
            "line": 0,
            "issue": "description",
            "fix": "suggested fix"
        }}
    ],
    "warnings": [],
    "fixed_code": "corrected code if errors found"
}}
"""
        response = self.think(prompt)
        try:
            result = json.loads(response)
            if result.get("syntax_ok") is True:
                return {"success": True, "syntax_ok": True, "rtl_code": rtl_code}
            else:
                return {
                    "success": True,
                    "syntax_ok": False,
                    "errors": result.get("errors", []),
                    "rtl_code": result.get("fixed_code", rtl_code)
                }
        except json.JSONDecodeError:
            if "SYNTAX_OK" in response:
                return {"success": True, "syntax_ok": True, "rtl_code": rtl_code}
            return {"success": False, "error": "Failed to parse response", "raw": response}


class PromptEnhancerAgent(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="PromptEnhancer",
            role="RTL Prompt Enhancer",
            goal="Enhance RTL generation prompts with module-specific context",
            backstory="""You are an expert at crafting effective prompts for RTL code
            generation. You understand what context helps generate better hardware
            description code.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        module_spec = context.get("current_module", {})
        kg = context.get("knowledge_graph", None)
        module_name = module_spec.get("name", "unknown")

        enhanced_context = {
            "module_name": module_name,
            "module_type": module_spec.get("type", "module"),
            "dependencies": module_spec.get("dependencies", []),
            "io_signals": self._extract_io_signals(module_spec),
            "configuration": module_spec.get("properties", {})
        }

        if kg:
            enhanced_context["connected_modules"] = self._get_connected_modules(kg, module_name)

        return {"success": True, "enhanced_context": enhanced_context}

    def _extract_io_signals(self, module_spec: Dict[str, Any]) -> List[Dict[str, Any]]:
        signals = []
        for inp in module_spec.get("inputs", []):
            signals.append({"name": inp.get("name"), "direction": "input", "width": inp.get("width", 1)})
        for out in module_spec.get("outputs", []):
            signals.append({"name": out.get("name"), "direction": "output", "width": out.get("width", 1)})
        return signals

    def _get_connected_modules(self, kg: KnowledgeGraph, module_name: str) -> List[str]:
        connected = []
        for edge in kg.edges:
            if edge.source == module_name:
                connected.append({"target": edge.target, "relationship": edge.edge_type.value})
            elif edge.target == module_name:
                connected.append({"source": edge.source, "relationship": edge.edge_type.value})
        return connected


class AssemblerAgent(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="Assembler",
            role="RTL Assembler",
            goal="Assemble individual RTL modules into a complete processor design",
            backstory="""You are a senior integration engineer who assembles individual
            RTL modules into a complete processor system. You ensure proper signal
            connections, clock/reset distribution, and module instantiation.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        rtl_modules = context.get("rtl_modules", {})
        module_order = context.get("module_order", [])
        kg = context.get("knowledge_graph", None)

        prompt = f"""Assemble the RTL modules into a complete RISC-V processor top-level module.

MODULES (in implementation order):
{json.dumps(module_order, indent=2)}

RTL MODULES AVAILABLE:
{json.dumps(list(rtl_modules.keys()), indent=2)}

Knowledge Graph Connections:
{kg.edges if kg else "No KG available"}

Create a top-level wrapper that:
1. Instantiates all modules in correct order
2. Connects signals according to the knowledge graph
3. Distributes clock and reset
4. Connects external interfaces (memory, interrupts, debug)
5. Properly parameterizes each instance

Output format:
```systemverilog
// RISC-V Processor Top Level
module riscv_core (
    // External interfaces
);
    // Clock and reset
    logic clk;
    logic rst_n;

    // Wire declarations for interconnects
    // ...

    // Module instantiations
    // ...

endmodule
```
"""
        response = self.think(prompt)
        top_level = self._extract_rtl(response)

        return {"success": True, "top_level": top_level}

    def _extract_rtl(self, response: str) -> str:
        match = re.search(r'```systemverilog\s*(.*?)\s*```', response, re.DOTALL)
        if match:
            return match.group(1)
        return response


class ProgressiveCodingPipeline:
    def __init__(self, llm_client: LLMClient):
        self.pseudo_coder = PseudoCoderAgent(llm_client)
        self.coder = CoderAgent(llm_client)
        self.syntax_checker = SyntaxCheckerAgent(llm_client)
        self.prompt_enhancer = PromptEnhancerAgent(llm_client)
        self.assembler = AssemblerAgent(llm_client)

    def generate_module(self, module_spec: Dict[str, Any], context: Dict[str, Any]) -> RTLModule:
        module_context = {
            **context,
            "current_module": module_spec
        }

        pseudo_result = self.pseudo_coder.execute(module_context)
        module_context["pseudo_code"] = pseudo_result.get("pseudo_code", "")

        coder_result = self.coder.execute(module_context)
        rtl_code = coder_result.get("rtl_code", "")
        module_context["rtl_code"] = rtl_code

        syntax_result = self.syntax_checker.execute(module_context)
        if syntax_result.get("syntax_ok"):
            rtl_code = syntax_result.get("rtl_code", rtl_code)
        else:
            errors = syntax_result.get("errors", [])
            rtl_code = syntax_result.get("rtl_code", rtl_code)

        module_name = module_spec.get("name", "unknown")
        return RTLModule(
            name=module_name,
            file_path=f"{module_name}.v",
            content=rtl_code,
            dependencies=module_spec.get("dependencies", []),
            syntax_errors=[]
        )

    def run(self, modules: List[Dict[str, Any]], context: Dict[str, Any]) -> Dict[str, Any]:
        rtl_modules = {}
        enhanced_contexts = {}

        for module_spec in modules:
            module_name = module_spec.get("name", "unknown")
            module_context = {
                **context,
                "current_module": module_spec
            }

            pseudo_result = self.pseudo_coder.execute(module_context)
            module_context["pseudo_code"] = pseudo_result.get("pseudo_code", "")

            coder_result = self.coder.execute(module_context)
            rtl_code = coder_result.get("rtl_code", "")
            module_context["rtl_code"] = rtl_code

            syntax_result = self.syntax_checker.execute(module_context)
            if syntax_result.get("syntax_ok"):
                rtl_code = syntax_result.get("rtl_code", rtl_code)
            else:
                rtl_code = syntax_result.get("rtl_code", rtl_code)

            rtl_modules[module_name] = RTLModule(
                name=module_name,
                file_path=f"{module_name}.v",
                content=rtl_code,
                dependencies=module_spec.get("dependencies", [])
            )

        assembler_context = {
            **context,
            "rtl_modules": {k: v.content for k, v in rtl_modules.items()},
            "module_order": [m.get("name") for m in modules]
        }
        assembler_result = self.assembler.execute(assembler_context)
        top_level = assembler_result.get("top_level", "")

        if top_level:
            rtl_modules["riscv_core"] = RTLModule(
                name="riscv_core",
                file_path="riscv_core.v",
                content=top_level,
                dependencies=list(rtl_modules.keys())
            )

        return {
            "success": True,
            "rtl_modules": rtl_modules,
            "top_level": top_level
        }
