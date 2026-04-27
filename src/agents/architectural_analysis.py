from typing import Dict, Any, List
import json
from .base import BaseAgent, LLMClient
from ..core.models import SpecDocument, AgentResult


class SummarizerAgent(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="Summarizer",
            role="Technical Documentation Summarizer",
            goal="Extract key architectural features and specifications from the document",
            backstory="""You are an expert at reading technical documentation and extracting
            the most important architectural decisions, module specifications, and interface
            definitions. You have deep knowledge of computer architecture, RTL design,
            and processor microarchitecture.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        spec_content = context.get("spec_content", "")
        if not spec_content:
            return {"success": False, "error": "No spec content provided"}

        prompt = f"""Analyze the following RISC-V processor specification and extract:

1. **Architecture Overview**: ISA type, pipeline depth, issue width, execution model
2. **Key Modules**: List all major modules (ALU, FPU, Cache, Register File, etc.)
3. **Pipeline Structure**: Number of stages, stage functions, data flow
4. **Interface Signals**: Clock, reset, memory interfaces, interrupt signals
5. **Critical Parameters**: Cache sizes, latencies, frequencies, widths

Provide a structured JSON summary with these fields.

SPEC:
{spec_content}

Output format (JSON only):
{{
    "architecture": {{
        "isa": "",
        "pipeline_stages": [],
        "issue_width": 0,
        "execution_model": ""
    }},
    "modules": [],
    "interfaces": [],
    "parameters": {{}}
}}
"""
        response = self.think(prompt)
        try:
            summary = json.loads(response)
            return {"success": True, "summary": summary}
        except json.JSONDecodeError as e:
            print(f"[DEBUG] JSON parse error: {e}")
            print(f"[DEBUG] Response content (first 500 chars): {response[:500]}")
            return {"success": False, "error": f"Failed to parse JSON: {e}", "raw_response": response[:1000]}


class DecomposerAgent(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="Decomposer",
            role="Architecture Decomposer",
            goal="Break down the processor specification into independent synthesizable modules",
            backstory="""You are a senior RTL architecture designer with experience designing
            complex processor systems. You excel at decomposing large specifications into
            smaller, independent, synthesizable modules that can be developed in parallel.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        summary = context.get("summary", {})
        if not summary:
            return {"success": False, "error": "No summary provided"}

        prompt = f"""Based on the following architecture summary, decompose the RISC-V processor
into independent RTL modules suitable for synthesis.

For each module provide:
- **Module Name**: Clear, hierarchical name
- **Functionality**: What it does
- **Inputs/Outputs**: Port interface (name, direction, width)
- **Dependencies**: Other modules it connects to
- **Implementation Priority**: 1-5 (1=highest, must be done first)

Modules to consider:
- Register Files (Integer, Floating-point, CSR)
- Execution Units (ALU, Multiplier, Divider, FPU)
- Pipeline Registers and Control
- Branch Prediction Unit
- Cache Controllers (I-Cache, D-Cache)
- Load/Store Unit
- Interrupt/Exception Controller
- Top-level processor wrapper

ARCHITECTURE SUMMARY:
{json.dumps(summary, indent=2)}

Output format (JSON array):
[
    {{
        "name": "module_name",
        "type": "module_type",
        "description": "",
        "inputs": [{{"name": "", "direction": "input/output", "width": 0}}],
        "outputs": [{{"name": "", "direction": "input/output", "width": 0}}],
        "dependencies": [],
        "priority": 1,
        "properties": {{}}
    }}
]
"""
        response = self.think(prompt)
        try:
            modules = json.loads(response)
            return {"success": True, "modules": modules}
        except json.JSONDecodeError:
            return {"success": False, "error": "Failed to parse JSON", "raw_response": response}


class SpecifierAgent(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="Specifier",
            role="RTL Specification Generator",
            goal="Generate detailed RTL specifications for each module",
            backstory="""You are an RTL specification expert who writes detailed, synthesis-ready
            specifications for hardware modules. Your specifications include finite state machines,
            timing diagrams descriptions, and exact signal behaviors.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        modules = context.get("modules", [])
        spec_content = context.get("spec_content", "")
        if not modules:
            return {"success": False, "error": "No modules provided"}

        detailed_specs = {}
        for module in modules[:5]:
            module_name = module.get("name", "unknown")
            prompt = f"""Generate a detailed RTL specification for the following RISC-V module.

MODULE: {module_name}
DESCRIPTION: {module.get('description', '')}

Extract relevant specifications from:
{spec_content}

Provide:
1. **State Machine**: If applicable, describe FSM states and transitions
2. **Timing**: Cycle-by-cycle behavior
3. **Control Signals**: What controls the module's operation
4. **Data Path**: How data flows through the module
5. **Edge Cases**: Special conditions, error handling

Be precise and detailed. Output as JSON:
{{
    "module_name": "{module_name}",
    "fsm_states": [],
    "timing_diagram": "description",
    "control_signals": [],
    "data_path": "description",
    "edge_cases": [],
    "rtl_snippet": "optional pseudocode"
}}
"""
            response = self.think(prompt)
            try:
                spec = json.loads(response)
                detailed_specs[module_name] = spec
            except json.JSONDecodeError:
                detailed_specs[module_name] = {"raw": response}

        return {"success": True, "detailed_specs": detailed_specs}


class AuditorAgent(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="Auditor",
            role="Specification Auditor",
            goal="Verify completeness and consistency of the implementation plan",
            backstory="""You are a meticulous auditor with experience reviewing processor
            specifications and RTL designs. You catch missing pieces, inconsistencies,
            and potential issues before implementation begins.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        modules = context.get("modules", [])
        detailed_specs = context.get("detailed_specs", {})
        summary = context.get("summary", {})

        prompt = f"""Audit the following module decomposition for completeness and consistency.

ORIGINAL ARCHITECTURE SUMMARY:
{json.dumps(summary, indent=2)}

DECOMPOSED MODULES:
{json.dumps(modules, indent=2)}

DETAILED SPECS AVAILABLE:
{json.dumps(list(detailed_specs.keys()), indent=2)}

Check for:
1. **Coverage**: Does the decomposition cover all aspects of the architecture?
2. **Dependencies**: Are dependency graphs correct? Any circular dependencies?
3. **Interfaces**: Are all inter-module interfaces defined?
4. **Missing Modules**: Any modules that should exist but don't?
5. **Priority Conflicts**: Are priorities correctly ordered?

Output format (JSON):
{{
    "audit_passed": true/false,
    "issues": [
        {{
            "severity": "critical/major/minor",
            "type": "coverage/dependency/interface/missing/priority",
            "description": "",
            "recommendation": ""
        }}
    ],
    "module_coverage": {{
        "covered": [],
        "missing": []
    }},
    "dependency_graph_valid": true/false,
    "interface_coverage": "percentage"
}}
"""
        response = self.think(prompt)
        try:
            audit_result = json.loads(response)
            return {"success": True, "audit": audit_result}
        except json.JSONDecodeError:
            return {"success": False, "error": "Failed to parse JSON", "raw_response": response}


class ArchitecturalAnalysisPipeline:
    def __init__(self, llm_client: LLMClient):
        self.summarizer = SummarizerAgent(llm_client)
        self.decomposer = DecomposerAgent(llm_client)
        self.specifier = SpecifierAgent(llm_client)
        self.auditor = AuditorAgent(llm_client)

    def run(self, spec_content: str) -> Dict[str, Any]:
        context = {"spec_content": spec_content}

        summary_result = self.summarizer.execute(context)
        if not summary_result.get("success"):
            return summary_result
        context["summary"] = summary_result["summary"]

        modules_result = self.decomposer.execute(context)
        if not modules_result.get("success"):
            return modules_result
        context["modules"] = modules_result["modules"]

        specs_result = self.specifier.execute(context)
        context["detailed_specs"] = specs_result.get("detailed_specs", {})

        audit_result = self.auditor.execute(context)
        context["audit"] = audit_result.get("audit", {})

        return {
            "success": True,
            "summary": context["summary"],
            "modules": context["modules"],
            "detailed_specs": context["detailed_specs"],
            "audit": context["audit"]
        }
