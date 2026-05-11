"""
File and directory management utilities for VeriGraph.
Handles module directory creation, file saving, and path resolution.
"""

import os
import json
from pathlib import Path
from typing import Optional


class FileManager:
    """Manages file operations across the VeriGraph project."""

    def __init__(self, project_root: str = "."):
        self.project_root = os.path.abspath(project_root)
        self._ensure_dirs()

    def _ensure_dirs(self):
        """Ensure all required directories exist."""
        dirs = [
            "modules",
            "logs/agents",
            "logs/intermediate",
            "logs/compilation",
            "logs/simulation",
            "logs/synthesis",
            "checkpoints",
            "knowledge_graph",
            "output/rtl",
            "output/tests",
        ]
        for d in dirs:
            os.makedirs(os.path.join(self.project_root, d), exist_ok=True)

    def module_dir(self, module_name: str) -> str:
        """Get the directory path for a specific module."""
        d = os.path.join(self.project_root, "modules", module_name)
        os.makedirs(d, exist_ok=True)
        return d

    def rtl_path(self, module_name: str) -> str:
        """Get the RTL file path for a module."""
        return os.path.join(self.module_dir(module_name), f"{module_name}.v")

    def tb_path(self, module_name: str) -> str:
        """Get the testbench file path for a module."""
        return os.path.join(self.module_dir(module_name), f"tb_{module_name}.v")

    def spec_path(self, module_name: str) -> str:
        """Get the spec/metadata file path for a module."""
        return os.path.join(self.module_dir(module_name), "spec.json")

    def rtl_exists(self, module_name: str) -> bool:
        """Check if RTL file exists for a module."""
        return os.path.exists(self.rtl_path(module_name))

    def tb_exists(self, module_name: str) -> bool:
        """Check if testbench file exists for a module."""
        return os.path.exists(self.tb_path(module_name))

    def read_rtl(self, module_name: str) -> Optional[str]:
        """Read RTL file content."""
        path = self.rtl_path(module_name)
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                return f.read()
        return None

    def read_tb(self, module_name: str) -> Optional[str]:
        """Read testbench file content."""
        path = self.tb_path(module_name)
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                return f.read()
        return None

    def save_rtl(self, module_name: str, code: str, version: int = 1):
        """Save RTL code to module directory."""
        path = self.rtl_path(module_name)
        with open(path, "w", encoding="utf-8") as f:
            f.write(code)

        # Versioned backup
        vpath = os.path.join(self.module_dir(module_name), f"{module_name}_v{version}.v")
        with open(vpath, "w", encoding="utf-8") as f:
            f.write(code)

    def save_tb(self, module_name: str, code: str):
        """Save testbench code to module directory."""
        path = self.tb_path(module_name)
        with open(path, "w", encoding="utf-8") as f:
            f.write(code)

    def save_spec(self, module_name: str, spec: dict):
        """Save module specification metadata."""
        path = self.spec_path(module_name)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(spec, f, indent=2, ensure_ascii=False)

    def read_spec(self, module_name: str) -> Optional[dict]:
        """Read module specification metadata."""
        path = self.spec_path(module_name)
        if os.path.exists(path):
            with open(path, "r", encoding="utf-8") as f:
                return json.load(f)
        return None

    def collect_all_rtl(self, output_dir: str = "./output/rtl") -> list:
        """Collect paths of all generated RTL files (only latest version, no testbenches)."""
        modules_dir = os.path.join(self.project_root, "modules")
        rtl_files = []
        if os.path.exists(modules_dir):
            for mod in sorted(os.listdir(modules_dir)):
                rtl_path = os.path.join(modules_dir, mod, f"{mod}.v")
                if os.path.exists(rtl_path):
                    rtl_files.append(rtl_path)
        return rtl_files

    def save_top_level_rtl(self, code: str, output_dir: str = "./output/rtl"):
        """Save top-level wrapper RTL."""
        os.makedirs(output_dir, exist_ok=True)
        path = os.path.join(output_dir, "rv32i_core.v")
        with open(path, "w", encoding="utf-8") as f:
            f.write(code)
        return path

    def save_all_rtl_to_output(self):
        """Copy all module RTL files to the output directory."""
        output_dir = os.path.join(self.project_root, "output", "rtl")
        os.makedirs(output_dir, exist_ok=True)
        modules_dir = os.path.join(self.project_root, "modules")
        copied = []
        if os.path.exists(modules_dir):
            for mod in sorted(os.listdir(modules_dir)):
                src = os.path.join(modules_dir, mod, f"{mod}.v")
                if os.path.exists(src):
                    dst = os.path.join(output_dir, f"{mod}.v")
                    with open(src, "r") as f:
                        content = f.read()
                    with open(dst, "w") as f:
                        f.write(content)
                    copied.append(dst)
        return copied


# Module dependency order for generation (leaf modules first, top-level last)
MODULE_ORDER = [
    # Functional units (no dependencies on other modules)
    "alu",
    "imm_gen",
    "control_unit",
    "reg_file",
    # Pipeline registers (depend only on clock/reset)
    "if_id_reg",
    "id_ex_reg",
    "ex_mem_reg",
    "mem_wb_reg",
    # Hazard unit (depends on ID/EX/MEM/WB interfaces)
    "hazard_unit",
    # Pipeline stages (depend on functional units and pipeline registers)
    "if_stage",
    "id_stage",
    "ex_stage",
    "mem_stage",
    "wb_stage",
    # Top-level (depends on all submodules)
    "rv32i_core",
]

MODULE_CATEGORIES = {
    "functional_units": ["alu", "imm_gen", "control_unit", "reg_file"],
    "pipeline_registers": ["if_id_reg", "id_ex_reg", "ex_mem_reg", "mem_wb_reg"],
    "control": ["hazard_unit"],
    "pipeline_stages": ["if_stage", "id_stage", "ex_stage", "mem_stage", "wb_stage"],
    "top_level": ["rv32i_core"],
}

MODULE_DEPENDENCIES = {
    "rv32i_core": ["if_stage", "id_stage", "ex_stage", "mem_stage", "wb_stage",
                    "reg_file", "alu", "imm_gen", "control_unit", "hazard_unit",
                    "if_id_reg", "id_ex_reg", "ex_mem_reg", "mem_wb_reg"],
    "if_stage": [],
    "id_stage": ["control_unit", "imm_gen", "reg_file"],
    "ex_stage": ["alu"],
    "mem_stage": [],
    "wb_stage": ["reg_file"],
    "hazard_unit": [],
    "alu": [],
    "imm_gen": [],
    "control_unit": [],
    "reg_file": [],
    "if_id_reg": [],
    "id_ex_reg": [],
    "ex_mem_reg": [],
    "mem_wb_reg": [],
}
