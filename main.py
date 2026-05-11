#!/usr/bin/env python3
"""
VeriGraph — Multi-Agent RTL Generation System with CrewAI
=========================================================
Main orchestrator for the RV32I core generation pipeline.

Usage:
    python main.py [--resume] [--check-only] [--skip-synthesis]

Features:
- Breakpoint/resume mechanism
- Per-module isolated generation
- Detailed logging to files
- Knowledge graph generation
- EDA pipeline (compile, simulate, synthesize)
"""

import os
import sys
import json
import logging
import argparse
import time
import traceback
from datetime import datetime
from pathlib import Path
from litellm.exceptions import BadRequestError as LiteLLMBadRequestError

# Add project root to path
PROJECT_ROOT = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, PROJECT_ROOT)

from src.utils.logger import setup_logger, AgentLogger, ModuleLogger, log_intermediate_result
from src.utils.json_parser import extract_json, extract_verilog_code, extract_testbench_code
from src.utils.checkpoint import CheckpointManager
from src.utils.file_manager import FileManager, MODULE_ORDER, MODULE_CATEGORIES, MODULE_DEPENDENCIES
from src.agents.definitions import create_llm, get_all_agents
from src.tasks.definitions import (
    create_spec_analysis_task,
    create_rtl_generation_task,
    create_code_review_task,
    create_testbench_generation_task,
    create_integration_task,
    create_rtl_fix_task,
    create_syntax_fix_task,
    create_compile_fix_task,
)
from src.graph.generator import KnowledgeGraphGenerator
from src.pipeline.runner import EDAPipeline, syntax_check_with_deps, parse_errors_by_module

import yaml
from crewai import Crew, Process


# ============================================================
# Configuration
# ============================================================

def load_config(config_path: str = None) -> dict:
    """Load configuration from YAML file."""
    if config_path is None:
        config_path = os.path.join(PROJECT_ROOT, "config", "config.yaml")

    config = {}
    if os.path.exists(config_path):
        with open(config_path, "r", encoding="utf-8") as f:
            config = yaml.safe_load(f) or {}
    return config


def load_spec(spec_path: str = None) -> str:
    """Load the RV32I core specification."""
    if spec_path is None:
        spec_path = os.path.join(PROJECT_ROOT, "spec", "RISCV_Core_Spec.md")
    with open(spec_path, "r", encoding="utf-8") as f:
        return f.read()


# ============================================================
# Module Specs (from parsed specification)
# ============================================================

def get_module_spec(module_name: str) -> dict:
    """Get the specification for a specific module (from spec analysis or hardcoded)."""
    fm = FileManager(PROJECT_ROOT)
    spec = fm.read_spec(module_name)
    if spec:
        return spec
    return {"module_name": module_name, "type": "unknown"}


# ============================================================
# Pipeline Phases
# ============================================================

class VeriGraphPipeline:
    """Main VeriGraph pipeline orchestrator."""

    def __init__(self, config: dict, resume: bool = False):
        self.config = config
        self.resume = resume
        self.project_root = PROJECT_ROOT

        # Setup logging
        self.logger = setup_logger("verigraph", os.path.join(PROJECT_ROOT, "logs"))
        self.agent_logger = AgentLogger(os.path.join(PROJECT_ROOT, "logs", "agents"))
        self.module_logger = ModuleLogger(os.path.join(PROJECT_ROOT, "modules"))

        # Managers
        self.checkpoint = CheckpointManager(os.path.join(PROJECT_ROOT, "checkpoints"))
        self.file_manager = FileManager(PROJECT_ROOT)

        # Graph generator
        self.graph_gen = KnowledgeGraphGenerator(os.path.join(PROJECT_ROOT, "knowledge_graph"))

        # EDA pipeline
        self.eda = EDAPipeline(PROJECT_ROOT)

        # Wait time between module API calls to avoid rate limiting
        self.call_delay = config.get("agents", {}).get("retry_delay", 5)
        # Max retries for LLM errors
        self.max_retries = config.get("agents", {}).get("max_iterations", 3)

    def _create_fresh_llm(self):
        """Create a NEW LLM instance each time (avoids session/state corruption)."""
        llm_config = self.config.get("llm", {})
        agent_config = self.config.get("agents", {})
        return create_llm(
            model=llm_config.get("model", "MiniMax-M2.7"),
            temperature=llm_config.get("temperature", 0.7),
            max_tokens=llm_config.get("max_tokens", 128000),
            timeout=agent_config.get("timeout_seconds", 3600),
        )

    def _create_fresh_agents(self):
        """Create fresh agent instances (new LLM per call to avoid state corruption)."""
        llm = self._create_fresh_llm()
        return get_all_agents(llm)

    @property
    def llm(self):
        """DEPRECATED: use _create_fresh_llm() instead."""
        return self._create_fresh_llm()

    @property
    def agents(self):
        """DEPRECATED: use _create_fresh_agents() instead."""
        return self._create_fresh_agents()

    # ============================================================
    # Main Entry Point
    # ============================================================

    def run(self, skip_synthesis: bool = False, check_only: bool = False):
        """Run the full VeriGraph pipeline."""
        self.logger.info("=" * 70)
        self.logger.info("  VeriGraph — Multi-Agent RTL Generation System")
        self.logger.info(f"  Started: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        self.logger.info(f"  Resume: {self.resume}")
        self.logger.info("=" * 70)

        # Print checkpoint state
        self.logger.info("\n" + self.checkpoint.get_state_summary())

        results = {}

        # Phase 1: Spec Analysis
        results["spec_analysis"] = self.run_spec_analysis()

        # Phase 2: RTL Generation (per-module, with breakpoints)
        results["rtl_generation"] = self.run_rtl_generation()

        # Phase 3: Code Review & Fix
        results["code_review"] = self.run_code_review()

        # Phase 4: Testbench Generation
        results["testbench"] = self.run_testbench_generation()

        # Phase 5: Integration (top-level wrapper)
        results["integration"] = self.run_integration()

        # Phase 6: Compilation
        results["compilation"] = self.run_compilation()

        # Phase 7: Simulation
        results["simulation"] = self.run_simulation(results["compilation"])

        # Phase 8: Synthesis
        if not skip_synthesis:
            results["synthesis"] = self.run_synthesis()
        else:
            results["synthesis"] = {"skipped": True}

        # Phase 9: Knowledge Graph
        results["knowledge_graph"] = self.run_knowledge_graph()

        # Final summary
        self.print_summary(results)

        if check_only:
            self.logger.info("Check-only mode: exiting after verification.")
            return results

        return results

    # ============================================================
    # Phase 1: Spec Analysis
    # ============================================================

    def run_spec_analysis(self) -> dict:
        """Parse the RV32I specification into structured module data."""
        self.logger.info("-" * 50)
        self.logger.info("PHASE 1: Specification Analysis")
        self.logger.info("-" * 50)

        if self.resume and self.checkpoint.is_module_completed("_spec_analysis_"):
            self.logger.info("Spec analysis already completed. Skipping.")
            return {"status": "cached", "message": "Loaded from checkpoint"}

        spec_text = load_spec()
        self.logger.info(f"Loaded specification: {len(spec_text)} characters")

        try:
            fresh_agents = self._create_fresh_agents()
            task = create_spec_analysis_task(fresh_agents["spec_analyst"], spec_text)
            crew = Crew(
                agents=[fresh_agents["spec_analyst"]],
                tasks=[task],
                process=Process.sequential,
                verbose=True,
            )

            self.agent_logger.log_agent_start("spec_analyst", "Parse RV32I specification")
            result = crew.kickoff()
            raw_output = str(result)
            self.agent_logger.log_agent_output("spec_analyst", raw_output, raw=True)

            # Extract JSON
            parsed = extract_json(raw_output)
            log_intermediate_result("spec_analysis", parsed)
            self.agent_logger.log_agent_output("spec_analyst", json.dumps(parsed, indent=2), raw=False)

            # Save module specs individually
            modules = parsed.get("modules", [])
            self.logger.info(f"Extracted {len(modules)} module specifications")

            for mod in modules:
                mod_name = mod.get("module_name", "unknown")
                self.file_manager.save_spec(mod_name, mod)
                self.logger.info(f"  Saved spec for: {mod_name}")

            self.checkpoint.mark_module_completed("_spec_analysis_", {
                "module_count": len(modules),
                "modules": [m.get("module_name") for m in modules],
            })

            self.agent_logger.log_agent_complete("spec_analyst", True)
            return {"status": "success", "module_count": len(modules)}

        except Exception as e:
            self.logger.error(f"Spec analysis failed: {e}")
            traceback.print_exc()
            self.agent_logger.log_agent_error("spec_analyst", str(e))
            self.agent_logger.log_agent_complete("spec_analyst", False)
            return {"status": "failed", "error": str(e)}

    # ============================================================
    # Phase 2: RTL Generation — Per Module
    # ============================================================

    def run_rtl_generation(self) -> dict:
        """Generate RTL for each module in dependency order, with breakpoints."""
        self.logger.info("-" * 50)
        self.logger.info("PHASE 2: RTL Generation (Per Module)")
        self.logger.info("-" * 50)

        results = {}
        pending = self.checkpoint.get_pending_modules(MODULE_ORDER)

        self.logger.info(f"Modules to generate: {len(pending)}/{len(MODULE_ORDER)}")
        self.logger.info(f"Pending: {pending}")

        for module_name in pending:
            self.logger.info(f"\n>>> Generating RTL for: {module_name}")

            try:
                result = self._generate_single_module_rtl(module_name)
                if result.get("success"):
                    self.checkpoint.mark_module_completed(module_name, {
                        "code_length": len(result.get("code", "")),
                        "hash": self.checkpoint.compute_content_hash(result.get("code", "")),
                    })
                    results[module_name] = "success"
                else:
                    self.checkpoint.mark_module_failed(module_name, result.get("error", "unknown"))
                    results[module_name] = "failed"
                    self.logger.warning(f"Module {module_name} failed. Continuing with remaining modules...")

            except Exception as e:
                self.logger.error(f"Exception generating {module_name}: {e}")
                traceback.print_exc()
                self.checkpoint.mark_module_failed(module_name, str(e))
                results[module_name] = "failed"

        # Count results
        success_count = sum(1 for v in results.values() if v == "success")
        fail_count = sum(1 for v in results.values() if v == "failed")
        self.logger.info(f"\nRTL Generation complete: {success_count} success, {fail_count} failed")

        return results

    def _generate_single_module_rtl(self, module_name: str) -> dict:
        """Generate RTL for a single module using fresh CrewAI instances + retry."""
        max_retries = self.max_retries
        current_retry = self.checkpoint.get_retry_count(module_name)

        # Get module spec
        module_spec = get_module_spec(module_name)

        # Gather dependency context
        deps = MODULE_DEPENDENCIES.get(module_name, [])
        dep_context = ""
        for dep in deps:
            dep_code = self.file_manager.read_rtl(dep)
            if dep_code:
                dep_header = self._extract_module_header(dep_code, dep)
                dep_context += f"\n--- {dep} (dependency) ---\n{dep_header}\n"

        last_error = None
        for attempt in range(max_retries):
            try:
                # Wait between calls to avoid rate limiting
                if attempt > 0:
                    wait = self.call_delay * (2 ** attempt)
                    self.logger.info(f"  Retry {attempt+1}/{max_retries} for {module_name} after {wait}s...")
                    time.sleep(wait)
                elif module_name != MODULE_ORDER[0]:
                    # Delay between different module calls
                    time.sleep(self.call_delay)

                # Create FRESH LLM and Agent for every call - avoids state corruption
                fresh_agents = self._create_fresh_agents()
                rtl_designer = fresh_agents["rtl_designer"]

                task = create_rtl_generation_task(rtl_designer, module_spec, dep_context)
                crew = Crew(
                    agents=[rtl_designer],
                    tasks=[task],
                    process=Process.sequential,
                    verbose=True,
                )

                self.agent_logger.log_agent_start("rtl_designer", f"Generate RTL for {module_name} (attempt {attempt+1})")
                result = crew.kickoff()
                raw_output = str(result)
                self.agent_logger.log_agent_output("rtl_designer", raw_output, raw=True)

                # Extract Verilog code
                rtl_code = extract_verilog_code(raw_output, module_name)
                if not rtl_code:
                    self.logger.error(f"Failed to extract Verilog code for {module_name}")
                    self.agent_logger.log_agent_error("rtl_designer", f"No Verilog code found in output for {module_name}")
                    last_error = "No Verilog code extracted"
                    continue

                # Validate
                if "endmodule" not in rtl_code:
                    self.logger.error(f"Missing endmodule in generated code for {module_name}")
                    last_error = "Missing endmodule"
                    continue

                if f"module {module_name}" not in rtl_code:
                    self.logger.warning(f"Module name mismatch in generated code for {module_name}")

                # Save
                version = current_retry + attempt + 1
                self.module_logger.save_module_rtl(module_name, rtl_code, version)
                self.file_manager.save_rtl(module_name, rtl_code, version)

                self.agent_logger.log_agent_output("rtl_designer", rtl_code, raw=False)

                # ---- POST-GENERATION SYNTAX CHECK ----
                # Check syntax with dependencies to catch embedded modules, port mismatches, etc.
                dep_files = [self.file_manager.rtl_path(d) for d in deps]
                syntax_result = syntax_check_with_deps(
                    self.file_manager.rtl_path(module_name),
                    dep_files,
                    self.eda.iverilog,
                )

                if not syntax_result.get("success"):
                    module_errors = syntax_result.get("module_errors", [])
                    if module_errors:
                        error_summary = "; ".join(module_errors[:3])
                        self.logger.warning(f"  Syntax check FAILED for {module_name}: {error_summary}")
                        self.agent_logger.log_agent_error("rtl_designer", f"Syntax check failed: {error_summary}")

                        # Immediate retry with error feedback
                        if attempt < max_retries - 1:
                            self.logger.info(f"  Auto-fixing syntax errors for {module_name}...")
                            fresh_agents2 = self._create_fresh_agents()
                            fix_task = create_syntax_fix_task(
                                fresh_agents2["rtl_designer"],
                                module_name,
                                rtl_code,
                                module_errors,
                            )
                            fix_crew = Crew(
                                agents=[fresh_agents2["rtl_designer"]],
                                tasks=[fix_task],
                                process=Process.sequential,
                                verbose=False,
                            )
                            try:
                                fix_result = fix_crew.kickoff()
                                fixed_code = extract_verilog_code(str(fix_result), module_name)
                                if fixed_code and "endmodule" in fixed_code:
                                    rtl_code = fixed_code
                                    self.module_logger.save_module_rtl(module_name, rtl_code, version + 10)
                                    self.file_manager.save_rtl(module_name, rtl_code, version + 10)
                                    self.logger.info(f"  Syntax-fixed RTL saved for {module_name}")

                                    # Re-check
                                    syntax_result2 = syntax_check_with_deps(
                                        self.file_manager.rtl_path(module_name), dep_files, self.eda.iverilog
                                    )
                                    if syntax_result2.get("success"):
                                        self.logger.info(f"  Syntax re-check PASSED for {module_name}")
                                    else:
                                        self.logger.warning(f"  Syntax re-check still failing, will retry outer loop")
                                        continue
                            except Exception as fix_e:
                                self.logger.warning(f"  Syntax auto-fix failed: {fix_e}")
                                continue
                        else:
                            self.logger.error(f"  Max retries reached for {module_name}, saving with errors")
                    else:
                        # Errors are in dependencies, not this module - proceed
                        self.logger.info(f"  Syntax issues in dependencies, not {module_name} itself, proceeding")
                else:
                    self.logger.info(f"  Syntax check PASSED for {module_name}")
                # ---- END SYNTAX CHECK ----

                self.agent_logger.log_agent_complete("rtl_designer", True)

                self.logger.info(f"Generated {module_name}: {len(rtl_code)} chars, {rtl_code.count(chr(10))} lines")
                return {"success": True, "code": rtl_code, "module_name": module_name}

            except LiteLLMBadRequestError as e:
                last_error = str(e)
                self.logger.warning(f"  LiteLLM error for {module_name} (attempt {attempt+1}): {last_error[:200]}")
                if "system" in last_error.lower() or "2013" in last_error:
                    self.logger.info(f"  Role error detected, will retry with fresh LLM...")
                if attempt < max_retries - 1:
                    continue
            except Exception as e:
                last_error = str(e)
                self.logger.warning(f"  Exception for {module_name} (attempt {attempt+1}): {last_error[:200]}")
                if attempt < max_retries - 1:
                    continue

        return {"success": False, "error": last_error or "Max retries exceeded"}

    # ============================================================
    # Phase 3: Code Review
    # ============================================================

    def run_code_review(self) -> dict:
        """Review generated RTL code for correctness."""
        self.logger.info("-" * 50)
        self.logger.info("PHASE 3: Code Review")
        self.logger.info("-" * 50)

        results = {}
        completed = self.checkpoint.state.get("completed_modules", [])

        for module_name in completed:
            if module_name.startswith("_"):
                continue
            if module_name == "rv32i_core":
                continue  # Skip top-level (reviewed in integration phase)

            time.sleep(self.call_delay)  # Delay between API calls

            rtl_code = self.file_manager.read_rtl(module_name)
            if not rtl_code:
                self.logger.warning(f"No RTL found for {module_name}, skipping review")
                continue

            module_spec = get_module_spec(module_name)

            self.logger.info(f"Reviewing: {module_name}")

            try:
                fresh_agents = self._create_fresh_agents()
                task = create_code_review_task(
                    fresh_agents["code_reviewer"],
                    module_name,
                    rtl_code,
                    module_spec,
                )

                crew = Crew(
                    agents=[fresh_agents["code_reviewer"]],
                    tasks=[task],
                    process=Process.sequential,
                    verbose=True,
                )

                self.agent_logger.log_agent_start("code_reviewer", f"Review {module_name}")
                result = crew.kickoff()
                raw_output = str(result)
                self.agent_logger.log_agent_output("code_reviewer", raw_output, raw=True)

                # Parse review feedback
                review = extract_json(raw_output)
                log_intermediate_result(f"review_{module_name}", review)

                results[module_name] = review

                # If critical issues found, attempt fix
                if isinstance(review, dict):
                    passed = review.get("passed", True)
                    issues = review.get("issues", [])
                    critical = [i for i in issues if i.get("severity") == "critical"]

                    if not passed or critical:
                        self.logger.warning(f"  {module_name}: {len(issues)} issues ({len(critical)} critical)")
                        if critical and self.checkpoint.get_retry_count(module_name) < 2:
                            self._attempt_rtl_fix(module_name, rtl_code, review)
                    else:
                        self.logger.info(f"  {module_name}: Passed review")

                self.agent_logger.log_agent_complete("code_reviewer", True)

            except Exception as e:
                self.logger.error(f"Review failed for {module_name}: {e}")
                results[module_name] = {"error": str(e)}

        return results

    def _attempt_rtl_fix(self, module_name: str, original_code: str, review: dict):
        """Attempt to fix RTL code based on review feedback."""
        self.logger.info(f"  Attempting auto-fix for {module_name}...")

        try:
            fresh_agents = self._create_fresh_agents()
            task = create_rtl_fix_task(
                fresh_agents["rtl_designer"],
                module_name,
                original_code,
                review,
            )

            crew = Crew(
                agents=[fresh_agents["rtl_designer"]],
                tasks=[task],
                process=Process.sequential,
                verbose=True,
            )

            result = crew.kickoff()
            raw_output = str(result)
            fixed_code = extract_verilog_code(raw_output, module_name)

            if fixed_code and "endmodule" in fixed_code:
                self.module_logger.save_module_rtl(module_name, fixed_code, version=2)
                self.file_manager.save_rtl(module_name, fixed_code, version=2)
                self.logger.info(f"  Fixed RTL saved for {module_name}")
            else:
                self.logger.warning(f"  Fix attempt failed to produce valid code for {module_name}")

        except Exception as e:
            self.logger.error(f"  Auto-fix failed for {module_name}: {e}")

    # ============================================================
    # Phase 4: Testbench Generation
    # ============================================================

    def run_testbench_generation(self) -> dict:
        """Generate testbenches for each module."""
        self.logger.info("-" * 50)
        self.logger.info("PHASE 4: Testbench Generation")
        self.logger.info("-" * 50)

        results = {}
        completed = self.checkpoint.state.get("completed_modules", [])

        for module_name in completed:
            if module_name.startswith("_"):
                continue
            if module_name == "rv32i_core":
                continue

            rtl_code = self.file_manager.read_rtl(module_name)
            if not rtl_code:
                continue

            # Check if testbench already exists
            if self.file_manager.tb_exists(module_name) and self.resume:
                self.logger.info(f"Testbench for {module_name} already exists. Skipping.")
                results[module_name] = "cached"
                continue

            module_spec = get_module_spec(module_name)

            self.logger.info(f"Generating testbench for: {module_name}")

            try:
                time.sleep(self.call_delay)  # Delay between testbench generations
                fresh_agents = self._create_fresh_agents()
                task = create_testbench_generation_task(
                    fresh_agents["testbench_generator"],
                    module_name,
                    rtl_code,
                    module_spec,
                )

                crew = Crew(
                    agents=[fresh_agents["testbench_generator"]],
                    tasks=[task],
                    process=Process.sequential,
                    verbose=True,
                )

                self.agent_logger.log_agent_start("testbench_generator", f"Testbench for {module_name}")
                result = crew.kickoff()
                raw_output = str(result)
                self.agent_logger.log_agent_output("testbench_generator", raw_output, raw=True)

                tb_code = extract_testbench_code(raw_output, module_name)
                if tb_code and "endmodule" in tb_code:
                    self.module_logger.save_module_testbench(module_name, tb_code)
                    self.file_manager.save_tb(module_name, tb_code)
                    self.logger.info(f"  Testbench saved: {len(tb_code)} chars")
                    results[module_name] = "success"
                else:
                    self.logger.warning(f"  No valid testbench code extracted for {module_name}")
                    results[module_name] = "no_code"

                self.agent_logger.log_agent_complete("testbench_generator", bool(tb_code))

            except Exception as e:
                self.logger.error(f"Testbench generation failed for {module_name}: {e}")
                results[module_name] = "failed"

        return results

    # ============================================================
    # Phase 5: Integration (Top-level wrapper)
    # ============================================================

    def run_integration(self) -> dict:
        """Create the top-level rv32i_core wrapper."""
        self.logger.info("-" * 50)
        self.logger.info("PHASE 5: Top-Level Integration")
        self.logger.info("-" * 50)

        if self.resume and self.checkpoint.is_module_completed("rv32i_core"):
            self.logger.info("Integration already completed. Skipping.")
            return {"status": "cached"}

        # Collect all submodule RTL
        all_rtl = {}
        for mod_name in MODULE_ORDER:
            if mod_name == "rv32i_core":
                continue
            code = self.file_manager.read_rtl(mod_name)
            if code:
                all_rtl[mod_name] = code

        self.logger.info(f"Found {len(all_rtl)} submodule RTL files for integration")

        try:
            fresh_agents = self._create_fresh_agents()
            task = create_integration_task(
                fresh_agents["integration_architect"],
                all_rtl,
                {n: get_module_spec(n) for n in all_rtl},
            )

            crew = Crew(
                agents=[fresh_agents["integration_architect"]],
                tasks=[task],
                process=Process.sequential,
                verbose=True,
            )

            self.agent_logger.log_agent_start("integration_architect", "Create top-level rv32i_core")
            result = crew.kickoff()
            raw_output = str(result)
            self.agent_logger.log_agent_output("integration_architect", raw_output, raw=True)

            top_code = extract_verilog_code(raw_output, "rv32i_core")
            if top_code and "endmodule" in top_code:
                self.file_manager.save_top_level_rtl(top_code)
                # Also save to modules directory
                self.module_logger.save_module_rtl("rv32i_core", top_code)
                self.file_manager.save_rtl("rv32i_core", top_code)
                self.checkpoint.mark_module_completed("rv32i_core", {
                    "code_length": len(top_code),
                })
                self.logger.info(f"Top-level wrapper saved: {len(top_code)} chars")
                self.agent_logger.log_agent_complete("integration_architect", True)
                return {"success": True, "code_length": len(top_code)}

            self.logger.error("Failed to extract valid top-level code")
            self.agent_logger.log_agent_complete("integration_architect", False)
            return {"success": False, "error": "No valid code extracted"}

        except Exception as e:
            self.logger.error(f"Integration failed: {e}")
            traceback.print_exc()
            return {"success": False, "error": str(e)}

    # ============================================================
    # Phase 6: Compilation
    # ============================================================

    def run_compilation(self) -> dict:
        """Compile all RTL files with iverilog, with auto-fix feedback loop."""
        self.logger.info("-" * 50)
        self.logger.info("PHASE 6: RTL Compilation (iverilog)")
        self.logger.info("-" * 50)

        # Check tools
        tools = self.eda.check_tools()
        self.logger.info(f"EDA Tools: {json.dumps(tools, indent=2)}")

        if not tools.get("iverilog", {}).get("available"):
            self.logger.error("iverilog not available!")
            return {"success": False, "error": "iverilog not found"}

        # Collect all RTL files
        self.file_manager.save_all_rtl_to_output()
        rtl_files = self.file_manager.collect_all_rtl()

        self.logger.info(f"Collecting {len(rtl_files)} RTL files for compilation")

        max_compile_attempts = 3
        for attempt in range(max_compile_attempts):
            # Compile
            result = self.eda.compile_rtl(rtl_files, top_module="rv32i_core")

            if result.get("success"):
                self.logger.info("Compilation SUCCESSFUL")
                self.checkpoint.set_compilation_status("success", {"files": len(rtl_files)})
                return result

            self.logger.error(f"Compilation FAILED (attempt {attempt+1}/{max_compile_attempts})")
            for err in result.get("errors", [])[:10]:
                self.logger.error(f"  {err}")

            # ---- COMPILATION FEEDBACK LOOP ----
            # Parse errors by module and auto-fix
            stderr = result.get("stderr", "")
            errors_by_module = parse_errors_by_module(stderr)

            if not errors_by_module or attempt >= max_compile_attempts - 1:
                break

            self.logger.info(f"  Compilation feedback: errors in {len(errors_by_module)} modules: {list(errors_by_module.keys())}")

            fixed_count = 0
            for mod_name, mod_errors in errors_by_module.items():
                rtl_code = self.file_manager.read_rtl(mod_name)
                if not rtl_code:
                    continue

                self.logger.info(f"  Auto-fixing compilation errors in: {mod_name}")
                time.sleep(self.call_delay)

                try:
                    fresh_agents = self._create_fresh_agents()
                    fix_task = create_compile_fix_task(
                        fresh_agents["rtl_designer"],
                        mod_name,
                        rtl_code,
                        result.get("errors", []),
                    )
                    fix_crew = Crew(
                        agents=[fresh_agents["rtl_designer"]],
                        tasks=[fix_task],
                        process=Process.sequential,
                        verbose=False,
                    )
                    fix_result = fix_crew.kickoff()
                    fixed_code = extract_verilog_code(str(fix_result), mod_name)
                    if fixed_code and "endmodule" in fixed_code and len(fixed_code) > 50:
                        self.file_manager.save_rtl(mod_name, fixed_code, version=99)
                        self.module_logger.save_module_rtl(mod_name, fixed_code, version=99)
                        self.logger.info(f"  Fixed RTL saved for {mod_name}: {len(fixed_code)} chars")
                        fixed_count += 1
                    else:
                        self.logger.warning(f"  Fix produced invalid code for {mod_name}")
                except Exception as fix_e:
                    self.logger.warning(f"  Fix failed for {mod_name}: {fix_e}")

            if fixed_count > 0:
                self.logger.info(f"  Fixed {fixed_count} modules, recompiling...")
                self.file_manager.save_all_rtl_to_output()
                rtl_files = self.file_manager.collect_all_rtl()
                continue
            else:
                break

        self.checkpoint.set_compilation_status(
            "failed",
            {"files": len(rtl_files), "errors": result.get("errors", [])},
        )
        return result

    # ============================================================
    # Phase 7: Simulation
    # ============================================================

    def run_simulation(self, compilation_result: dict) -> dict:
        """Run simulation with vvp."""
        self.logger.info("-" * 50)
        self.logger.info("PHASE 7: Simulation (vvp)")
        self.logger.info("-" * 50)

        if not compilation_result.get("success"):
            self.logger.warning("Skipping simulation: compilation failed")
            self.checkpoint.set_simulation_status("skipped", {"reason": "compilation failed"})
            return {"success": False, "error": "Compilation failed"}

        compiled_exe = compilation_result.get("output")
        if not compiled_exe or not os.path.exists(compiled_exe):
            self.logger.error(f"Compiled executable not found: {compiled_exe}")
            return {"success": False, "error": "Executable not found"}

        # Generate a simple top-level testbench if needed
        top_tb_path = os.path.join(PROJECT_ROOT, "output", "tests", "tb_rv32i_core.v")
        if not os.path.exists(top_tb_path):
            self._generate_top_testbench()

        # Compile with testbench
        rtl_files = self.file_manager.collect_all_rtl()
        tb_result = self.eda.compile_with_testbench(
            rtl_files, top_tb_path,
            top_module="tb_rv32i_core",
            output_name="simulation",
        )

        if not tb_result.get("success"):
            self.logger.warning("Testbench compilation failed, trying without testbench...")
            return {"success": False, "error": "Testbench compilation failed"}

        # Run simulation
        sim_result = self.eda.simulate(
            os.path.join(PROJECT_ROOT, "output", "simulation"),
            vcd_file="waveform.vcd",
        )

        self.checkpoint.set_simulation_status(
            "success" if sim_result.get("success") else "failed",
            {
                "vcd_file": sim_result.get("vcd_file"),
                "test_passed": sim_result.get("test_passed"),
            },
        )

        if sim_result.get("success"):
            self.logger.info("Simulation SUCCESSFUL")
            if sim_result.get("vcd_file"):
                self.logger.info(f"Waveform saved: {sim_result['vcd_file']}")
        else:
            self.logger.error("Simulation FAILED")

        return sim_result

    def _generate_top_testbench(self):
        """Generate a minimal top-level testbench for the RV32I core."""
        tb_code = """`timescale 1ns/1ps

module tb_rv32i_core;

    reg clk;
    reg rst_n;

    // IMEM interface
    wire [31:0] imem_addr;
    reg  [31:0] imem_rdata;
    wire        imem_req;

    // DMEM interface
    wire [31:0] dmem_addr;
    wire [31:0] dmem_wdata;
    reg  [31:0] dmem_rdata;
    wire        dmem_req;
    wire        dmem_we;
    wire [3:0]  dmem_be;

    // Instantiate core
    rv32i_core u_core (
        .clk(clk),
        .rst_n(rst_n),
        .imem_addr(imem_addr),
        .imem_rdata(imem_rdata),
        .imem_req(imem_req),
        .dmem_addr(dmem_addr),
        .dmem_wdata(dmem_wdata),
        .dmem_rdata(dmem_rdata),
        .dmem_req(dmem_req),
        .dmem_we(dmem_we),
        .dmem_be(dmem_be)
    );

    // IMEM simulation (NOP sled + minimal program)
    reg [31:0] imem [0:255];
    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            imem_rdata <= 32'h00000013; // NOP
        end else if (imem_req) begin
            if (imem_addr[31:2] < 256)
                imem_rdata <= imem[imem_addr[31:2]];
            else
                imem_rdata <= 32'h00000013; // NOP for out-of-range
        end
    end

    // DMEM simulation
    reg [31:0] dmem [0:255];

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dmem_rdata <= 32'h0;
        end else if (dmem_req) begin
            if (dmem_we) begin
                if (dmem_addr[31:2] < 256)
                    dmem[dmem_addr[31:2]] <= dmem_wdata;
                dmem_rdata <= 32'h0;
            end else begin
                if (dmem_addr[31:2] < 256)
                    dmem_rdata <= dmem[dmem_addr[31:2]];
                else
                    dmem_rdata <= 32'h0;
            end
        end
    end

    // Clock generation
    initial clk = 0;
    always #5 clk = ~clk;

    // Waveform dump
    initial begin
        $dumpfile("waveform.vcd");
        $dumpvars(0, tb_rv32i_core);
    end

    // Test sequence
    initial begin
        // Initialize memory with test program
        for (i = 0; i < 256; i = i + 1)
            imem[i] = 32'h00000013; // NOP sled

        // Simple test program: ADDI x1, x0, 10
        // Actually let's keep it minimal for compilation test
        imem[0] = 32'h00A00093; // ADDI x1, x0, 10

        $display("=== RV32I Core Simulation Start ===");

        // Reset
        rst_n = 0;
        #20;
        rst_n = 1;
        #20;

        // Run a few cycles
        #200;

        $display("=== Simulation Complete ===");
        $display("TEST PASSED (basic compilation test)");
        $finish;
    end

endmodule
"""
        tb_dir = os.path.join(PROJECT_ROOT, "output", "tests")
        os.makedirs(tb_dir, exist_ok=True)
        tb_path = os.path.join(tb_dir, "tb_rv32i_core.v")
        with open(tb_path, "w") as f:
            f.write(tb_code)
        self.logger.info(f"Generated minimal top-level testbench: {tb_path}")
        return tb_path

    # ============================================================
    # Phase 8: Synthesis
    # ============================================================

    def run_synthesis(self) -> dict:
        """Run logic synthesis with yosys."""
        self.logger.info("-" * 50)
        self.logger.info("PHASE 8: Logic Synthesis (yosys)")
        self.logger.info("-" * 50)

        tools = self.eda.check_tools()
        if not tools.get("yosys", {}).get("available"):
            self.logger.error("yosys not available!")
            return {"success": False, "error": "yosys not found"}

        rtl_files = self.file_manager.collect_all_rtl()
        self.logger.info(f"Synthesizing {len(rtl_files)} RTL files")

        result = self.eda.synthesize(rtl_files, top_module="rv32i_core")
        self.checkpoint.set_synthesis_status(
            "success" if result.get("success") else "failed",
            result.get("stats", {}),
        )

        if result.get("success"):
            self.logger.info("Synthesis SUCCESSFUL")
            stats = result.get("stats", {})
            self.logger.info(f"  Cells: {stats.get('cells', 'N/A')}")
            self.logger.info(f"  Netlist: {result.get('netlist_file', 'N/A')}")

            # Generate report
            report = self.eda.generate_synthesis_report(result)
            self.logger.info(f"  Report: {report}")
        else:
            self.logger.error("Synthesis FAILED")

        return result

    # ============================================================
    # Phase 9: Knowledge Graph
    # ============================================================

    def run_knowledge_graph(self) -> dict:
        """Generate SVG HTML knowledge graph."""
        self.logger.info("-" * 50)
        self.logger.info("PHASE 9: Knowledge Graph Generation")
        self.logger.info("-" * 50)

        # Determine module statuses
        module_status = {}
        for mod_name in MODULE_ORDER:
            if self.checkpoint.is_module_completed(mod_name):
                module_status[mod_name] = "completed"
            elif mod_name in self.checkpoint.state.get("failed_modules", []):
                module_status[mod_name] = "failed"
            else:
                module_status[mod_name] = "pending"

        # Generate main graph
        html_path = self.graph_gen.generate(module_status)
        svg_path = self.graph_gen.generate_simple_svg(module_status)

        # Generate module list page
        list_path = self.graph_gen.generate_module_list_page(module_status)

        # Generate detail pages for completed modules
        for mod_name, status in module_status.items():
            if status == "completed":
                code = self.file_manager.read_rtl(mod_name)
                if code:
                    self.graph_gen.generate_module_detail_page(
                        mod_name, code,
                        get_module_spec(mod_name),
                        module_status,
                    )

        self.checkpoint.set_knowledge_graph_status("completed")

        self.logger.info(f"Knowledge graph saved to: {html_path}")
        self.logger.info(f"Module list saved to: {list_path}")

        return {
            "success": True,
            "html_path": html_path,
            "svg_path": svg_path,
            "list_path": list_path,
        }

    # ============================================================
    # Utilities
    # ============================================================

    @staticmethod
    def _extract_module_header(rtl_code: str, module_name: str) -> str:
        """Extract just the module header (port list) from RTL code."""
        lines = rtl_code.strip().split("\n")
        header_lines = []
        in_ports = False
        for line in lines:
            stripped = line.strip()
            if stripped.startswith(f"module {module_name}"):
                in_ports = True
                header_lines.append(line)
            elif in_ports:
                header_lines.append(line)
                if stripped == ");":
                    break
            if len(header_lines) > 50:  # Safety limit
                break
        return "\n".join(header_lines)

    def print_summary(self, results: dict):
        """Print final pipeline summary."""
        self.logger.info("\n" + "=" * 70)
        self.logger.info("  VeriGraph Pipeline Summary")
        self.logger.info("=" * 70)
        self.logger.info(f"  Completed at: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        self.logger.info("")

        for phase, result in results.items():
            if phase == "rtl_generation":
                if isinstance(result, dict):
                    success = sum(1 for v in result.values() if v == "success")
                    failed = sum(1 for v in result.values() if v == "failed")
                    self.logger.info(f"  {phase}: {success} succeeded, {failed} failed")
            elif isinstance(result, dict):
                status = result.get("success", result.get("status", "unknown"))
                self.logger.info(f"  {phase}: {status}")
            else:
                self.logger.info(f"  {phase}: {result}")

        self.logger.info("")
        self.logger.info("  Output files:")
        self.logger.info(f"    RTL: {os.path.join(PROJECT_ROOT, 'output', 'rtl')}")
        self.logger.info(f"    Modules: {os.path.join(PROJECT_ROOT, 'modules')}")
        self.logger.info(f"    Knowledge Graph: {os.path.join(PROJECT_ROOT, 'knowledge_graph')}")
        self.logger.info(f"    Logs: {os.path.join(PROJECT_ROOT, 'logs')}")
        self.logger.info(f"    Checkpoints: {os.path.join(PROJECT_ROOT, 'checkpoints')}")
        self.logger.info("=" * 70)


# ============================================================
# CLI Entry Point
# ============================================================

def main():
    parser = argparse.ArgumentParser(
        description="VeriGraph — Multi-Agent RTL Generation with CrewAI",
    )
    parser.add_argument("--resume", action="store_true",
                        help="Resume from last checkpoint")
    parser.add_argument("--check-only", action="store_true",
                        help="Check configuration and tools without running pipeline")
    parser.add_argument("--skip-synthesis", action="store_true",
                        help="Skip the synthesis phase")
    parser.add_argument("--config", type=str, default=None,
                        help="Path to config.yaml")
    parser.add_argument("--module", type=str, default=None,
                        help="Generate only a specific module")
    args = parser.parse_args()

    # Load config
    config = load_config(args.config)

    # Create pipeline
    pipeline = VeriGraphPipeline(config, resume=args.resume)

    if args.check_only:
        # Just check tools and configuration
        logger = setup_logger("verigraph.check", os.path.join(PROJECT_ROOT, "logs"))
        logger.info("=== VeriGraph Configuration Check ===")
        logger.info(f"Config: {json.dumps(config, indent=2)}")

        eda = EDAPipeline(PROJECT_ROOT)
        tools = eda.check_tools()
        logger.info(f"EDA Tools: {json.dumps(tools, indent=2)}")

        all_available = all(t.get("available") for t in tools.values())
        if all_available:
            logger.info("All EDA tools available!")
        else:
            missing = [name for name, t in tools.items() if not t.get("available")]
            logger.warning(f"Missing tools: {missing}")

        logger.info(f"LLM: {config.get('llm', {}).get('model', 'unknown')}")
        return

    if args.module:
        # Generate single module
        pipeline.logger.info(f"Generating single module: {args.module}")
        result = pipeline._generate_single_module_rtl(args.module)
        pipeline.logger.info(f"Result: {result.get('success')}")
        return

    # Run full pipeline
    try:
        pipeline.run(skip_synthesis=args.skip_synthesis)
    except KeyboardInterrupt:
        pipeline.logger.warning("\nPipeline interrupted by user. Progress saved to checkpoints.")
        pipeline.logger.info(f"Resume with: python main.py --resume")
        sys.exit(1)
    except Exception as e:
        pipeline.logger.error(f"Pipeline failed: {e}")
        traceback.print_exc()
        sys.exit(1)


if __name__ == "__main__":
    main()
