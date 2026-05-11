"""
Comprehensive logging system for VeriGraph.
All agent outputs, intermediate results, and pipeline outputs are logged to files.
"""

import os
import logging
import logging.handlers
import sys
from datetime import datetime
from pathlib import Path


def setup_logger(
    name: str,
    log_dir: str = "./logs",
    level: int = logging.DEBUG,
    console_level: int = logging.INFO,
) -> logging.Logger:
    """
    Create a logger with both file and console handlers.

    Args:
        name: Logger name
        log_dir: Directory for log files
        level: File logging level
        console_level: Console logging level

    Returns:
        Configured logger instance
    """
    os.makedirs(log_dir, exist_ok=True)

    logger = logging.getLogger(name)
    logger.setLevel(logging.DEBUG)  # Capture everything, handlers filter
    logger.handlers.clear()
    logger.propagate = False

    # File handler - detailed
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    file_handler = logging.FileHandler(
        os.path.join(log_dir, f"{name}_{timestamp}.log"),
        encoding="utf-8",
    )
    file_handler.setLevel(level)
    file_formatter = logging.Formatter(
        "%(asctime)s | %(levelname)-8s | %(name)s | %(funcName)s:%(lineno)d | %(message)s",
        datefmt="%Y-%m-%d %H:%M:%S",
    )
    file_handler.setFormatter(file_formatter)
    logger.addHandler(file_handler)

    # Console handler - less verbose
    console_handler = logging.StreamHandler(sys.stdout)
    console_handler.setLevel(console_level)
    console_formatter = logging.Formatter(
        "[%(levelname)-5s] %(name)s | %(message)s",
    )
    console_handler.setFormatter(console_formatter)
    logger.addHandler(console_handler)

    return logger


class AgentLogger:
    """Specialized logger for CrewAI agent outputs."""

    def __init__(self, log_dir: str = "./logs/agents"):
        self.log_dir = log_dir
        os.makedirs(log_dir, exist_ok=True)
        self._base_logger = logging.getLogger("verigraph.agents")

    def log_agent_start(self, agent_name: str, task_description: str):
        """Log when an agent starts a task."""
        filepath = os.path.join(self.log_dir, f"{agent_name}_execution.log")
        with open(filepath, "a", encoding="utf-8") as f:
            f.write(f"\n{'=' * 80}\n")
            f.write(f"AGENT: {agent_name}\n")
            f.write(f"TIMESTAMP: {datetime.now().isoformat()}\n")
            f.write(f"TASK: {task_description[:500]}\n")
            f.write(f"{'=' * 80}\n\n")
        self._base_logger.info(f"[START] {agent_name}")

    def log_agent_output(self, agent_name: str, output: str, raw: bool = True):
        """Log agent output (both raw and processed)."""
        filepath = os.path.join(self.log_dir, f"{agent_name}_execution.log")
        label = "RAW OUTPUT" if raw else "PROCESSED OUTPUT"
        with open(filepath, "a", encoding="utf-8") as f:
            f.write(f"\n--- {label} ---\n")
            f.write(output)
            f.write(f"\n--- END {label} ---\n\n")
        truncated = output[:200] + "..." if len(output) > 200 else output
        self._base_logger.info(f"[OUTPUT] {agent_name}: {truncated}")

    def log_agent_error(self, agent_name: str, error: str):
        """Log agent errors."""
        filepath = os.path.join(self.log_dir, f"{agent_name}_execution.log")
        with open(filepath, "a", encoding="utf-8") as f:
            f.write(f"\n!!! ERROR !!!\n{error}\n!!! END ERROR !!!\n\n")
        self._base_logger.error(f"[ERROR] {agent_name}: {error}")

    def log_agent_complete(self, agent_name: str, success: bool):
        """Log agent completion."""
        filepath = os.path.join(self.log_dir, f"{agent_name}_execution.log")
        status = "SUCCESS" if success else "FAILED"
        with open(filepath, "a", encoding="utf-8") as f:
            f.write(f"\n--- AGENT COMPLETE: {agent_name} [{status}] ---\n")
            f.write(f"TIMESTAMP: {datetime.now().isoformat()}\n\n")
        self._base_logger.info(f"[COMPLETE] {agent_name}: {status}")


class ModuleLogger:
    """Logger for per-module intermediate results."""

    def __init__(self, modules_dir: str = "./modules"):
        self.modules_dir = modules_dir
        os.makedirs(modules_dir, exist_ok=True)
        self._base_logger = logging.getLogger("verigraph.modules")

    def save_module_rtl(self, module_name: str, rtl_code: str, version: int = 1):
        """Save generated RTL code for a module."""
        module_dir = os.path.join(self.modules_dir, f"{module_name}")
        os.makedirs(module_dir, exist_ok=True)
        filepath = os.path.join(module_dir, f"{module_name}.v")
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(rtl_code)
        self._base_logger.info(f"Saved RTL: {filepath} ({len(rtl_code)} chars)")

        # Also save versioned copy
        version_path = os.path.join(module_dir, f"{module_name}_v{version}.v")
        with open(version_path, "w", encoding="utf-8") as f:
            f.write(rtl_code)

        # Save metadata
        meta_path = os.path.join(module_dir, "metadata.txt")
        with open(meta_path, "a", encoding="utf-8") as f:
            f.write(f"Version {version}: {datetime.now().isoformat()} - {len(rtl_code)} chars\n")

    def save_module_testbench(self, module_name: str, tb_code: str):
        """Save testbench for a module."""
        module_dir = os.path.join(self.modules_dir, f"{module_name}")
        os.makedirs(module_dir, exist_ok=True)
        filepath = os.path.join(module_dir, f"tb_{module_name}.v")
        with open(filepath, "w", encoding="utf-8") as f:
            f.write(tb_code)
        self._base_logger.info(f"Saved testbench: {filepath}")

    def save_module_metadata(self, module_name: str, metadata: dict):
        """Save structured metadata for a module."""
        import json
        module_dir = os.path.join(self.modules_dir, f"{module_name}")
        os.makedirs(module_dir, exist_ok=True)
        filepath = os.path.join(module_dir, "spec.json")
        with open(filepath, "w", encoding="utf-8") as f:
            json.dump(metadata, f, indent=2, ensure_ascii=False)
        self._base_logger.info(f"Saved metadata: {filepath}")

    def read_module_rtl(self, module_name: str) -> str | None:
        """Read previously generated RTL for a module."""
        filepath = os.path.join(self.modules_dir, f"{module_name}", f"{module_name}.v")
        if os.path.exists(filepath):
            with open(filepath, "r", encoding="utf-8") as f:
                return f.read()
        return None

    def module_exists(self, module_name: str) -> bool:
        """Check if a module has already been generated."""
        filepath = os.path.join(self.modules_dir, f"{module_name}", f"{module_name}.v")
        return os.path.exists(filepath)


def log_intermediate_result(stage: str, data: dict | str, log_dir: str = "./logs/intermediate"):
    """Save intermediate results to a JSON file."""
    import json
    os.makedirs(log_dir, exist_ok=True)
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filepath = os.path.join(log_dir, f"{stage}_{timestamp}.json")
    with open(filepath, "w", encoding="utf-8") as f:
        if isinstance(data, str):
            json.dump({"stage": stage, "data": data}, f, indent=2, ensure_ascii=False)
        else:
            data["stage"] = stage
            data["timestamp"] = datetime.now().isoformat()
            json.dump(data, f, indent=2, ensure_ascii=False)
    return filepath
