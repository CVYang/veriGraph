from typing import Dict, Any, List
import json
from .base import BaseAgent, LLMClient
from ..core.models import RTLModule, KnowledgeGraph


class VerifierAgent(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="Verifier",
            role="RTL Verification Engineer",
            goal="Generate verification testbenches and validate RTL correctness",
            backstory="""You are an experienced verification engineer who writes
            comprehensive testbenches and validation scripts for processor designs.
            You understand RISC-V ISA, instruction encoding, and functional verification.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        rtl_modules = context.get("rtl_modules", {})
        spec_content = context.get("spec_content", "")

        if not rtl_modules:
            return {"success": False, "error": "No RTL modules provided"}

        testbenches = {}
        for module_name, module in rtl_modules.items():
            tb = self._generate_testbench(module_name, module.content, spec_content)
            testbenches[module_name] = tb

        return {
            "success": True,
            "testbenches": testbenches,
            "verification_status": "completed"
        }

    def _generate_testbench(self, module_name: str, rtl_code: str, spec_content: str) -> str:
        prompt = f"""Generate a SystemVerilog testbench for the following RISC-V module.

MODULE: {module_name}
RTL CODE:
{rtl_code[:2000]}

SPEC CONTEXT:
{spec_content[:1500]}

The testbench should:
1. Instantiate the DUT (Device Under Test)
2. Generate clock and reset signals
3. Apply test vectors based on module functionality
4. Monitor outputs and check for expected values
5. Include timeout protection
6. Print pass/fail status

For RISC-V specific modules:
- Register File: Test all register writes/reads, x0 special case
- ALU: Test all arithmetic and logical operations
- FPU: Test IEEE 754 compliance, exception cases
- Cache: Test hits, misses, write-back, replacement
- Pipeline: Test instruction flow, hazard handling

Output format:
```systemverilog
// Testbench for module_name
module tb_module_name;
    // Clock and reset generation
    logic clk;
    logic rst_n;

    // DUT instantiation
    module_name dut (/* ports */);

    // Test stimulus
    initial begin
        // Test cases
    end

    // Monitoring and assertions
endmodule
```
"""
        response = self.think(prompt)
        return self._extract_testbench(response)

    def _extract_testbench(self, response: str) -> str:
        import re
        match = re.search(r'```systemverilog\s*(.*?)\s*```', response, re.DOTALL)
        if match:
            return match.group(1)
        return response


class SynthesisValidatorAgent(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="SynthesisValidator",
            role="Synthesis Validation Engineer",
            goal="Validate RTL is synthesis-ready and identify potential issues",
            backstory="""You are a synthesis expert who reviews RTL code for
            synthesis readiness. You understand FSM encoding, clocking,
            reset strategies, and common synthesis pitfalls.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        rtl_modules = context.get("rtl_modules", {})
        validation_results = {}

        for module_name, module in rtl_modules.items():
            result = self._validate_synthesis(module_name, module.content)
            validation_results[module_name] = result

        return {
            "success": True,
            "validation_results": validation_results
        }

    def _validate_synthesis(self, module_name: str, rtl_code: str) -> Dict[str, Any]:
        prompt = f"""Analyze the following RTL for synthesis readiness.

MODULE: {module_name}
CODE:
{rtl_code}

Check for:
1. **Clocking Issues**: Multiple clocks, missing clock assignments
2. **Reset Strategy**: Async vs sync reset, reset release
3. **FSM Encoding**: One-hot, binary, gray code appropriateness
4. **Combinational Loops**: Feedback without proper registration
5. **Incomplete Case Statements**: Missing default, all cases covered
6. **Latch Inference**: Missing else branches, incomplete assignments
7. **Clock Gating**: Proper enable conditions
8. **Synthesis Attributes**: parallel_case, full_case directives

Provide specific issues and severity levels.

Output format (JSON):
{{
    "synthesis_ready": true/false,
    "issues": [
        {{
            "severity": "critical/major/minor",
            "type": "clocking/reset/fsm/combinational/case/latch",
            "location": "description",
            "issue": "problem description",
            "recommendation": "fix recommendation"
        }}
    ],
    "score": 0-100
}}
"""
        response = self.think(prompt)
        try:
            import json
            result = json.loads(response)
            return result
        except:
            return {"synthesis_ready": False, "error": "Parse failed", "raw": response}


class VerificationPipeline:
    def __init__(self, llm_client: LLMClient):
        self.verifier = VerifierAgent(llm_client)
        self.synthesis_validator = SynthesisValidatorAgent(llm_client)

    def run(self, rtl_modules: Dict[str, RTLModule], spec_content: str) -> Dict[str, Any]:
        context = {
            "rtl_modules": {k: v for k, v in rtl_modules.items()},
            "spec_content": spec_content
        }

        verification_result = self.verifier.execute(context)
        validation_result = self.synthesis_validator.execute(context)

        return {
            "success": True,
            "testbenches": verification_result.get("testbenches", {}),
            "verification_status": verification_result.get("verification_status", "unknown"),
            "synthesis_validation": validation_result.get("validation_results", {}),
            "all_modules_synthesis_ready": all(
                v.get("synthesis_ready", False)
                for v in validation_result.get("validation_results", {}).values()
            )
        }
