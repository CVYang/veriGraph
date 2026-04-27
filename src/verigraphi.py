import os
import sys
import json
import yaml
import logging
from typing import Dict, Any, Optional, List
from pathlib import Path
from datetime import datetime

from .agents.base import LLMClient
from .agents.architectural_analysis import ArchitecturalAnalysisPipeline
from .agents.hierarchy_analysis import HierarchyAnalysisPipeline
from .agents.progressive_coding import ProgressiveCodingPipeline
from .agents.verification import VerificationPipeline
from .core.models import KnowledgeGraph, ImplementationPlan, RTLModule


class CheckpointManager:
    def __init__(self, output_dir: str):
        self.output_dir = Path(output_dir)
        self.checkpoint_dir = self.output_dir / ".checkpoints"
        self.checkpoint_dir.mkdir(parents=True, exist_ok=True)
        self.log_dir = self.output_dir / "logs"
        self.log_dir.mkdir(parents=True, exist_ok=True)

        logging.basicConfig(
            level=logging.INFO,
            format='%(asctime)s [%(levelname)s] %(message)s',
            handlers=[
                logging.FileHandler(self.log_dir / f"verigraphi_{datetime.now().strftime('%Y%m%d_%H%M%S')}.log"),
                logging.StreamHandler(sys.stdout)
            ]
        )
        self.logger = logging.getLogger("VeriGraphi")

    def save_checkpoint(self, stage: str, data: Dict[str, Any]):
        checkpoint_file = self.checkpoint_dir / f"{stage}.json"
        with open(checkpoint_file, 'w') as f:
            json.dump(data, f, indent=2, default=str)
        self.logger.info(f"[CHECKPOINT] Saved: {stage}")

    def load_checkpoint(self, stage: str) -> Optional[Dict[str, Any]]:
        checkpoint_file = self.checkpoint_dir / f"{stage}.json"
        if checkpoint_file.exists():
            with open(checkpoint_file, 'r') as f:
                return json.load(f)
        return None

    def checkpoint_exists(self, stage: str) -> bool:
        return (self.checkpoint_dir / f"{stage}.json").exists()

    def save_rtl_module(self, module_name: str, content: str):
        rtl_dir = self.output_dir / "rtl"
        rtl_dir.mkdir(parents=True, exist_ok=True)
        module_path = rtl_dir / f"{module_name}.v"
        with open(module_path, 'w') as f:
            f.write(content)
        self.logger.info(f"[CHECKPOINT] Saved RTL: {module_name}.v")

    def save_intermediate(self, name: str, data: Any):
        intermediate_dir = self.output_dir / "intermediate"
        intermediate_dir.mkdir(parents=True, exist_ok=True)
        file_path = intermediate_dir / f"{name}.json"
        with open(file_path, 'w') as f:
            json.dump(data, f, indent=2, default=str)
        self.logger.info(f"[CHECKPOINT] Saved intermediate: {name}")


class VeriGraphiPipeline:
    def __init__(self, api_key: str, model: str = "MiniMax-M2.7",
                 provider: str = "minimax", config_path: Optional[str] = None):
        self.api_key = api_key
        self.model = model
        self.provider = provider

        self.llm_client = LLMClient(
            provider=provider,
            api_key=api_key,
            model=model
        )

        self.config = self._load_config(config_path) if config_path else {}

        self.architectural_pipeline = ArchitecturalAnalysisPipeline(self.llm_client)
        self.hierarchy_pipeline = HierarchyAnalysisPipeline(self.llm_client)
        self.coding_pipeline = ProgressiveCodingPipeline(self.llm_client)
        self.verification_pipeline = VerificationPipeline(self.llm_client)

        self.checkpoint: Optional[CheckpointManager] = None

    def _load_config(self, config_path: str) -> Dict[str, Any]:
        with open(config_path, 'r') as f:
            return yaml.safe_load(f)

    def _log_stage(self, stage: str, message: str):
        print(f"\n{'='*60}")
        print(f"[STAGE] {stage}")
        print(f"{'='*60}")
        if self.checkpoint:
            self.checkpoint.logger.info(f"[STAGE] {stage} - {message}")

    def _log_substage(self, substage: str, message: str = ""):
        print(f"\n[  SUBSTAGE  ] {substage} {message}")
        if self.checkpoint:
            self.checkpoint.logger.info(f"[SUBSTAGE] {substage} - {message}")

    def run(self, spec_path: str, output_dir: str = "./output", resume: bool = False) -> Dict[str, Any]:
        self.checkpoint = CheckpointManager(output_dir)
        self.checkpoint.logger.info(f"Starting VeriGraphi pipeline")
        self.checkpoint.logger.info(f"Spec: {spec_path}")
        self.checkpoint.logger.info(f"Output: {output_dir}")
        self.checkpoint.logger.info(f"Resume: {resume}")

        output_path = Path(output_dir)
        output_path.mkdir(parents=True, exist_ok=True)
        (output_path / "rtl").mkdir(exist_ok=True)
        (output_path / "kg").mkdir(exist_ok=True)
        (output_path / "tests").mkdir(exist_ok=True)
        (output_path / "intermediate").mkdir(exist_ok=True)

        spec_content = self._read_spec(spec_path)
        if not spec_content:
            return {"success": False, "error": f"Failed to read spec file: {spec_path}"}

        self._log_stage("STAGE 1: Architectural Analysis", "Reading spec")
        self.checkpoint.save_intermediate("spec_content", {"spec_path": str(spec_path), "content_length": len(spec_content)})

        context = {
            "spec_content": spec_content,
            "spec_path": spec_path,
            "output_dir": str(output_path)
        }

        if resume and self.checkpoint.checkpoint_exists("stage1_summarizer"):
            self._log_substage("Resuming from checkpoint: stage1_summarizer")
            summary_result = self.checkpoint.load_checkpoint("stage1_summarizer")
        else:
            self._log_substage("SummarizerAgent", "Extracting architecture summary")
            summary_result = self.summarizer_execute(context)
            self.checkpoint.save_checkpoint("stage1_summarizer", summary_result)

        if not summary_result.get("success"):
            self.checkpoint.logger.error(f"Summarizer failed: {summary_result.get('error')}")
            return summary_result
        context["summary"] = summary_result.get("summary", {})
        self.checkpoint.save_intermediate("summary", context["summary"])
        self._log_substage("SummarizerAgent", f"Success - found {len(context['summary'].get('modules', []))} modules")

        if resume and self.checkpoint.checkpoint_exists("stage1_decomposer"):
            self._log_substage("Resuming from checkpoint: stage1_decomposer")
            modules_result = self.checkpoint.load_checkpoint("stage1_decomposer")
        else:
            self._log_substage("DecomposerAgent", "Decomposing into RTL modules")
            modules_result = self.decomposer_execute(context)
            self.checkpoint.save_checkpoint("stage1_decomposer", modules_result)

        if not modules_result.get("success"):
            self.checkpoint.logger.error(f"Decomposer failed: {modules_result.get('error')}")
            return modules_result
        context["modules"] = modules_result.get("modules", [])
        self.checkpoint.save_intermediate("modules", context["modules"])
        self._log_substage("DecomposerAgent", f"Success - decomposed into {len(context['modules'])} modules")

        if resume and self.checkpoint.checkpoint_exists("stage1_specifier"):
            self._log_substage("Resuming from checkpoint: stage1_specifier")
            specs_result = self.checkpoint.load_checkpoint("stage1_specifier")
        else:
            self._log_substage("SpecifierAgent", "Generating detailed specifications")
            specs_result = self.specifier_execute(context)
            self.checkpoint.save_checkpoint("stage1_specifier", specs_result)

        context["detailed_specs"] = specs_result.get("detailed_specs", {})
        self.checkpoint.save_intermediate("detailed_specs", context["detailed_specs"])
        self._log_substage("SpecifierAgent", f"Success - generated specs for {len(context['detailed_specs'])} modules")

        if resume and self.checkpoint.checkpoint_exists("stage1_auditor"):
            self._log_substage("Resuming from checkpoint: stage1_auditor")
            audit_result = self.checkpoint.load_checkpoint("stage1_auditor")
        else:
            self._log_substage("AuditorAgent", "Auditing implementation plan")
            audit_result = self.auditor_execute(context)
            self.checkpoint.save_checkpoint("stage1_auditor", audit_result)

        context["audit"] = audit_result.get("audit", {})
        self.checkpoint.save_intermediate("audit", context["audit"])
        self._log_substage("AuditorAgent", f"Success - audit passed: {context['audit'].get('audit_passed', False)}")

        architectural_result = {
            "success": True,
            "summary": context["summary"],
            "modules": context["modules"],
            "detailed_specs": context["detailed_specs"],
            "audit": context["audit"]
        }

        self._log_stage("STAGE 2: Knowledge Graph & Hierarchy Analysis", "Building KG and implementation plan")
        if resume and self.checkpoint.checkpoint_exists("stage2_kg"):
            self._log_substage("Resuming from checkpoint: stage2_kg")
            kg_result = self.checkpoint.load_checkpoint("stage2_kg")
        else:
            self._log_substage("KnowledgeGraphBuilder", "Building hierarchical knowledge graph")
            kg_result = self.kgbuilder_execute(context)
            self.checkpoint.save_checkpoint("stage2_kg", kg_result)

        if not kg_result.get("success"):
            self.checkpoint.logger.error(f"KG Builder failed: {kg_result.get('error')}")
            return kg_result

        kg = kg_result["knowledge_graph"]
        context["knowledge_graph"] = kg
        self.checkpoint.save_intermediate("knowledge_graph", {
            "nodes": [{"id": n.id, "name": n.name} for n in kg.nodes.values()],
            "edges": [{"source": e.source, "target": e.target} for e in kg.edges]
        })
        self._log_substage("KnowledgeGraphBuilder", f"Success - built KG with {len(kg.nodes)} nodes")

        if resume and self.checkpoint.checkpoint_exists("stage2_hierarchy"):
            self._log_substage("Resuming from checkpoint: stage2_hierarchy")
            plan_result = self.checkpoint.load_checkpoint("stage2_hierarchy")
        else:
            self._log_substage("HierarchyAnalyzer", "Analyzing module hierarchy")
            plan_result = self.hierarchy_analyzer_execute(context)
            self.checkpoint.save_checkpoint("stage2_hierarchy", plan_result)

        if not plan_result.get("success"):
            self.checkpoint.logger.error(f"Hierarchy Analyzer failed: {plan_result.get('error')}")
            return plan_result

        context["implementation_plan"] = plan_result["implementation_plan"]
        context["phases"] = plan_result.get("phases", [])
        self.checkpoint.save_intermediate("implementation_plan", {
            "phases": context["phases"],
            "module_order": plan_result["implementation_plan"].module_order,
            "dependencies": plan_result["implementation_plan"].dependencies
        })
        self._log_substage("HierarchyAnalyzer", f"Success - planned {len(context['phases'])} phases")

        self._log_stage("STAGE 3: Progressive RTL Coding", "Generating RTL modules")
        modules = architectural_result.get("modules", [])

        if resume and self.checkpoint.checkpoint_exists("stage3_coding"):
            self._log_substage("Resuming from checkpoint: stage3_coding")
            coding_result = self.checkpoint.load_checkpoint("stage3_coding")
        else:
            self._log_substage("ProgressiveCodingPipeline", f"Generating {len(modules)} RTL modules")
            coding_result = self.coding_pipeline.run(modules, context)
            self.checkpoint.save_checkpoint("stage3_coding", {
                "success": coding_result.get("success", False),
                "rtl_modules": {k: {"name": v.name, "content": v.content, "file_path": v.file_path}
                              for k, v in coding_result.get("rtl_modules", {}).items()}
            })

        if not coding_result.get("success"):
            self.checkpoint.logger.error(f"Coding failed: {coding_result.get('error')}")
            return coding_result

        context["rtl_modules"] = coding_result["rtl_modules"]
        for module_name, module in coding_result["rtl_modules"].items():
            if isinstance(module, RTLModule):
                self.checkpoint.save_rtl_module(module_name, module.content)

        self._log_substage("ProgressiveCodingPipeline", f"Success - generated {len(coding_result['rtl_modules'])} RTL modules")

        self._log_stage("STAGE 4: Verification", "Generating testbenches and validation")
        if self.config.get("pipeline", {}).get("enable_verification", True):
            self._log_substage("VerificationPipeline", "Running verification")
            verification_result = self.verification_pipeline.run(
                coding_result["rtl_modules"],
                spec_content
            )
            context["verification"] = verification_result

            testbenches = verification_result.get("testbenches", {})
            for module_name, tb in testbenches.items():
                tb_path = output_path / "tests" / f"tb_{module_name}.sv"
                with open(tb_path, 'w') as f:
                    f.write(tb)

            self.checkpoint.save_checkpoint("stage4_verification", verification_result)
            self._log_substage("VerificationPipeline", f"Success - generated {len(testbenches)} testbenches")
        else:
            verification_result = {"success": True, "skipped": True}
            self._log_substage("Verification", "Skipped (disabled in config)")

        self._log_stage("STAGE 5: Final Output", "Saving all outputs")
        self._save_outputs(context, str(output_path))

        self.checkpoint.logger.info("Pipeline completed successfully!")
        print(f"\n{'='*60}")
        print("[COMPLETE] VeriGraphi pipeline finished successfully!")
        print(f"{'='*60}")
        print(f"Output directory: {output_dir}")
        print(f"Modules generated: {', '.join(context['rtl_modules'].keys())}")

        return {
            "success": True,
            "output_dir": str(output_path),
            "modules_generated": list(context["rtl_modules"].keys()),
            "verification_status": verification_result.get("verification_status", "unknown"),
            "phases": context["phases"],
            "audit": architectural_result.get("audit", {})
        }

    def summarizer_execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        return self.architectural_pipeline.summarizer.execute(context)

    def decomposer_execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        return self.architectural_pipeline.decomposer.execute(context)

    def specifier_execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        return self.architectural_pipeline.specifier.execute(context)

    def auditor_execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        return self.architectural_pipeline.auditor.execute(context)

    def kgbuilder_execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        return self.hierarchy_pipeline.kg_builder.execute(context)

    def hierarchy_analyzer_execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        return self.hierarchy_pipeline.hierarchy_analyzer.execute(context)

    def _read_spec(self, spec_path: str) -> str:
        path = Path(spec_path)
        if not path.exists():
            spec_path = Path(__file__).parent.parent / spec_path
            path = Path(spec_path)
        if not path.exists():
            return ""
        with open(path, 'r') as f:
            return f.read()

    def _save_outputs(self, context: Dict[str, Any], output_dir: str):
        rtl_modules = context.get("rtl_modules", {})
        for module_name, module in rtl_modules.items():
            if isinstance(module, RTLModule):
                module_path = Path(output_dir) / "rtl" / module.file_path
                with open(module_path, 'w') as f:
                    f.write(module.content)

        kg = context.get("knowledge_graph")
        if kg:
            kg_path = Path(output_dir) / "kg" / "hda.json"
            kg_data = {
                "nodes": [
                    {
                        "id": n.id,
                        "name": n.name,
                        "node_type": n.node_type.value,
                        "description": n.description,
                        "interfaces": n.interfaces,
                        "properties": n.properties
                    }
                    for n in kg.nodes.values()
                ],
                "edges": [
                    {
                        "source": e.source,
                        "target": e.target,
                        "edge_type": e.edge_type.value,
                        "label": e.label
                    }
                    for e in kg.edges
                ]
            }
            with open(kg_path, 'w') as f:
                json.dump(kg_data, f, indent=2)

        plan = context.get("implementation_plan")
        if plan:
            plan_path = Path(output_dir) / "implementation_plan.json"
            plan_data = {
                "phases": plan.phases,
                "module_order": plan.module_order,
                "dependencies": plan.dependencies,
                "milestones": plan.milestones
            }
            with open(plan_path, 'w') as f:
                json.dump(plan_data, f, indent=2)

        testbenches = context.get("verification", {}).get("testbenches", {})
        for module_name, tb in testbenches.items():
            tb_path = Path(output_dir) / "tests" / f"tb_{module_name}.sv"
            with open(tb_path, 'w') as f:
                f.write(tb)

        summary = {
            "modules_generated": list(rtl_modules.keys()),
            "phases": context.get("phases", []),
            "verification_status": context.get("verification", {}).get("verification_status", "unknown"),
            "audit_passed": context.get("audit", {}).get("audit_passed", True)
        }
        summary_path = Path(output_dir) / "summary.json"
        with open(summary_path, 'w') as f:
            json.dump(summary, f, indent=2)


def create_pipeline(api_key: str, **kwargs) -> VeriGraphiPipeline:
    return VeriGraphiPipeline(api_key=api_key, **kwargs)
