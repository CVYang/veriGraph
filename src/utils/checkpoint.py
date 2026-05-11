"""
Checkpoint mechanism for resumable execution.
Saves progress after each module generation so the pipeline can be resumed from any point.
"""

import os
import json
import hashlib
import logging
from datetime import datetime
from typing import Optional

logger = logging.getLogger(__name__)


class CheckpointManager:
    """
    Manages execution checkpoints for breakpoint/resume functionality.

    Tracks:
    - Which modules have been generated
    - Which verification steps have been completed
    - Pipeline state (compilation, simulation, synthesis)
    - LLM interaction history
    """

    def __init__(self, checkpoint_dir: str = "./checkpoints"):
        self.checkpoint_dir = checkpoint_dir
        os.makedirs(checkpoint_dir, exist_ok=True)
        self.state_file = os.path.join(checkpoint_dir, "pipeline_state.json")
        self.state = self._load_state()

    def _load_state(self) -> dict:
        """Load existing pipeline state or create new."""
        if os.path.exists(self.state_file):
            try:
                with open(self.state_file, "r", encoding="utf-8") as f:
                    state = json.load(f)
                logger.info(f"Loaded checkpoint state: {len(state.get('completed_modules', []))} modules completed")
                return state
            except (json.JSONDecodeError, KeyError):
                logger.warning("Corrupted checkpoint state, starting fresh")
        return self._default_state()

    def _default_state(self) -> dict:
        return {
            "pipeline_version": "1.0",
            "created_at": datetime.now().isoformat(),
            "updated_at": datetime.now().isoformat(),
            "completed_modules": [],
            "module_details": {},
            "verification_results": {},
            "compilation": {"status": "pending", "timestamp": None},
            "simulation": {"status": "pending", "timestamp": None},
            "synthesis": {"status": "pending", "timestamp": None},
            "knowledge_graph": {"status": "pending", "timestamp": None},
            "failed_modules": [],
            "retry_counts": {},
        }

    def save(self):
        """Persist state to disk."""
        self.state["updated_at"] = datetime.now().isoformat()
        with open(self.state_file, "w", encoding="utf-8") as f:
            json.dump(self.state, f, indent=2, ensure_ascii=False)

    def is_module_completed(self, module_name: str) -> bool:
        """Check if a module has already been successfully generated."""
        return module_name in self.state["completed_modules"]

    def mark_module_completed(self, module_name: str, details: dict = None):
        """Mark a module as successfully generated."""
        if module_name not in self.state["completed_modules"]:
            self.state["completed_modules"].append(module_name)
        if details:
            self.state["module_details"][module_name] = details
            self.state["module_details"][module_name]["completed_at"] = datetime.now().isoformat()
        self.save()
        logger.info(f"Checkpoint: Module '{module_name}' marked as completed")

    def mark_module_failed(self, module_name: str, error: str):
        """Mark a module as failed."""
        if module_name not in self.state["failed_modules"]:
            self.state["failed_modules"].append(module_name)
        retries = self.state["retry_counts"].get(module_name, 0)
        self.state["retry_counts"][module_name] = retries + 1
        self.save()
        logger.warning(f"Checkpoint: Module '{module_name}' failed (retry {retries + 1}): {error[:200]}")

    def get_failed_modules(self) -> list:
        """Get list of modules that need retry."""
        return self.state["failed_modules"]

    def get_pending_modules(self, all_modules: list) -> list:
        """Get list of modules that haven't been completed yet."""
        completed = set(self.state["completed_modules"])
        return [m for m in all_modules if m not in completed]

    def get_retry_count(self, module_name: str) -> int:
        """Get number of retries for a module."""
        return self.state["retry_counts"].get(module_name, 0)

    def set_verification_result(self, module_name: str, result: dict):
        """Store verification results for a module."""
        self.state["verification_results"][module_name] = result
        self.save()

    def set_compilation_status(self, status: str, details: dict = None):
        """Update compilation status."""
        self.state["compilation"] = {
            "status": status,
            "timestamp": datetime.now().isoformat(),
            "details": details or {},
        }
        self.save()

    def set_simulation_status(self, status: str, details: dict = None):
        """Update simulation status."""
        self.state["simulation"] = {
            "status": status,
            "timestamp": datetime.now().isoformat(),
            "details": details or {},
        }
        self.save()

    def set_synthesis_status(self, status: str, details: dict = None):
        """Update synthesis status."""
        self.state["synthesis"] = {
            "status": status,
            "timestamp": datetime.now().isoformat(),
            "details": details or {},
        }
        self.save()

    def set_knowledge_graph_status(self, status: str):
        """Update knowledge graph status."""
        self.state["knowledge_graph"] = {
            "status": status,
            "timestamp": datetime.now().isoformat(),
        }
        self.save()

    def get_state_summary(self) -> str:
        """Return a human-readable summary of pipeline state."""
        s = self.state
        return (
            f"Pipeline State:\n"
            f"  Completed Modules: {len(s['completed_modules'])}/15\n"
            f"    {', '.join(s['completed_modules']) or 'none'}\n"
            f"  Failed Modules: {len(s['failed_modules'])}\n"
            f"  Compilation: {s['compilation']['status']}\n"
            f"  Simulation: {s['simulation']['status']}\n"
            f"  Synthesis: {s['synthesis']['status']}\n"
            f"  Knowledge Graph: {s['knowledge_graph']['status']}"
        )

    def clear_module_from_completed(self, module_name: str):
        """Remove a module from completed list (for re-generation)."""
        if module_name in self.state["completed_modules"]:
            self.state["completed_modules"].remove(module_name)
        self.save()

    def compute_content_hash(self, content: str) -> str:
        """Compute SHA256 hash of content for change detection."""
        return hashlib.sha256(content.encode()).hexdigest()[:16]
