"""
EDA Pipeline Runner — Compilation, Simulation, and Synthesis for VeriGraph.

Tools used:
- iverilog/vvp: Compilation and simulation (with VCD waveform)
- yosys: Logic synthesis (generates netlist, synthesis report)
"""

import os
import sys
import subprocess
import logging
import re
from datetime import datetime
from pathlib import Path
from typing import Optional

logger = logging.getLogger(__name__)


class EDAPipeline:
    """
    Manages the full EDA flow: compile → simulate → synthesize.

    Each step's logs are saved to dedicated directories.
    """

    def __init__(
        self,
        project_root: str = ".",
        iverilog_path: str = "",
        vvp_path: str = "",
        yosys_path: str = "",
    ):
        self.project_root = os.path.abspath(project_root)
        self.iverilog = iverilog_path or self._find_tool("iverilog")
        self.vvp = vvp_path or self._find_tool("vvp")
        self.yosys = yosys_path or self._find_tool("yosys")

        self.log_dir = os.path.join(project_root, "logs")
        self.output_dir = os.path.join(project_root, "output")
        self.rtl_dir = os.path.join(self.output_dir, "rtl")
        self.tb_dir = os.path.join(self.output_dir, "tests")

        os.makedirs(os.path.join(self.log_dir, "compilation"), exist_ok=True)
        os.makedirs(os.path.join(self.log_dir, "simulation"), exist_ok=True)
        os.makedirs(os.path.join(self.log_dir, "synthesis"), exist_ok=True)
        os.makedirs(os.path.join(self.output_dir, "netlist"), exist_ok=True)
        os.makedirs(os.path.join(self.output_dir, "waveforms"), exist_ok=True)

    @staticmethod
    def _find_tool(name: str) -> str:
        """Find EDA tool in common locations."""
        paths = [
            os.path.expanduser("~/Documents/oss-cad-suite/bin"),
            "/usr/local/bin",
            "/usr/bin",
        ]
        for p in paths:
            candidate = os.path.join(p, name)
            if os.path.exists(candidate) and os.access(candidate, os.X_OK):
                return candidate
        # Fall back to PATH
        return name

    def check_tools(self) -> dict:
        """Check availability of all required EDA tools."""
        results = {}
        for name, path in [("iverilog", self.iverilog), ("vvp", self.vvp), ("yosys", self.yosys)]:
            try:
                result = subprocess.run([path, "--version"], capture_output=True, text=True, timeout=10)
                results[name] = {
                    "available": True,
                    "path": path,
                    "version": result.stdout.strip().split("\n")[0] if result.stdout else "unknown",
                }
            except (FileNotFoundError, subprocess.TimeoutExpired):
                results[name] = {"available": False, "path": path, "version": "not found"}
        return results

    def compile_rtl(self, rtl_files: list, top_module: str = "rv32i_core",
                    output_name: str = "rv32i_core_sim") -> dict:
        """
        Compile all RTL files with iverilog.

        Args:
            rtl_files: List of paths to Verilog source files
            top_module: Name of the top-level module
            output_name: Name for the compiled simulation executable

        Returns:
            Dict with compilation results
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = os.path.join(self.log_dir, "compilation", f"compile_{timestamp}.log")

        # Collect all RTL files
        src_files = []
        for f in rtl_files:
            if os.path.exists(f):
                src_files.append(f)
            else:
                logger.warning(f"RTL file not found: {f}")

        if not src_files:
            return {"success": False, "error": "No RTL files found for compilation"}

        # Write source file list
        flist_path = os.path.join(self.rtl_dir, "filelist.f")
        with open(flist_path, "w") as f:
            for sf in src_files:
                f.write(f"{sf}\n")

        # Build iverilog command
        output_exe = os.path.join(self.output_dir, output_name)
        cmd = [
            self.iverilog,
            "-g2012",
            "-o", output_exe,
        ]
        # Add include directories
        cmd.extend(["-I", self.rtl_dir])
        cmd.extend(["-I", os.path.join(self.project_root, "modules")])
        cmd.extend(src_files)

        logger.info(f"Compiling {len(src_files)} RTL files...")
        logger.debug(f"Command: {' '.join(cmd)}")

        try:
            result = subprocess.run(cmd, capture_output=True, text=True, timeout=300)

            with open(log_file, "w", encoding="utf-8") as f:
                f.write(f"=== Compilation Log ===\n")
                f.write(f"Timestamp: {datetime.now().isoformat()}\n")
                f.write(f"Command: {' '.join(cmd)}\n")
                f.write(f"Source files: {len(src_files)}\n")
                f.write(f"=== STDOUT ===\n{result.stdout}\n")
                f.write(f"=== STDERR ===\n{result.stderr}\n")
                f.write(f"=== Return Code: {result.returncode} ===\n")

            success = result.returncode == 0
            if success:
                logger.info(f"Compilation successful. Output: {output_exe}")
            else:
                logger.error(f"Compilation failed (code {result.returncode})")
                # Parse errors
                errors = self._parse_iverilog_errors(result.stderr)
                for e in errors[:5]:
                    logger.error(f"  {e}")

            return {
                "success": success,
                "log_file": log_file,
                "output": output_exe,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "errors": self._parse_iverilog_errors(result.stderr),
                "warnings": self._parse_iverilog_warnings(result.stderr + result.stdout),
            }

        except subprocess.TimeoutExpired:
            logger.error("Compilation timed out (300s)")
            return {"success": False, "error": "Compilation timed out"}
        except Exception as e:
            logger.error(f"Compilation error: {e}")
            return {"success": False, "error": str(e)}

    def compile_with_testbench(self, rtl_files: list, tb_file: str,
                               top_module: str = "rv32i_core_tb",
                               output_name: str = "simulation") -> dict:
        """Compile RTL with a testbench."""
        all_files = list(rtl_files)
        if os.path.exists(tb_file):
            all_files.append(tb_file)
        return self.compile_rtl(all_files, top_module, output_name)

    def simulate(self, compiled_exe: str, vcd_file: str = "waveform.vcd",
                 timeout: int = 60) -> dict:
        """
        Run simulation with vvp and generate VCD waveform.

        Args:
            compiled_exe: Path to the compiled simulation executable
            vcd_file: Name for the VCD waveform file
            timeout: Simulation timeout in seconds

        Returns:
            Dict with simulation results
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = os.path.join(self.log_dir, "simulation", f"simulate_{timestamp}.log")
        vcd_path = os.path.join(self.output_dir, "waveforms", vcd_file)

        if not os.path.exists(compiled_exe):
            return {"success": False, "error": f"Compiled executable not found: {compiled_exe}"}

        logger.info(f"Running simulation: {compiled_exe}")
        logger.info(f"VCD waveform: {vcd_path}")

        try:
            # vvp outputs VCD by design when $dumpfile/$dumpvars are in testbench
            result = subprocess.run(
                [self.vvp, compiled_exe],
                capture_output=True,
                text=True,
                timeout=timeout,
                cwd=os.path.join(self.output_dir, "waveforms"),
            )

            with open(log_file, "w", encoding="utf-8") as f:
                f.write(f"=== Simulation Log ===\n")
                f.write(f"Timestamp: {datetime.now().isoformat()}\n")
                f.write(f"Executable: {compiled_exe}\n")
                f.write(f"=== STDOUT ===\n{result.stdout}\n")
                f.write(f"=== STDERR ===\n{result.stderr}\n")
                f.write(f"=== Return Code: {result.returncode} ===\n")

            success = result.returncode == 0
            vcd_exists = os.path.exists(vcd_path)

            if success:
                logger.info(f"Simulation completed successfully")
                if vcd_exists:
                    logger.info(f"VCD waveform saved: {vcd_path}")
            else:
                logger.error(f"Simulation failed (code {result.returncode})")

            # Extract pass/fail from testbench output
            tb_passed = "PASS" in result.stdout or "Test passed" in result.stdout
            tb_failed = "FAIL" in result.stdout or "Error" in result.stdout

            return {
                "success": success and not tb_failed,
                "log_file": log_file,
                "vcd_file": vcd_path if vcd_exists else None,
                "stdout": result.stdout,
                "stderr": result.stderr,
                "test_passed": tb_passed,
                "test_failed": tb_failed,
            }

        except subprocess.TimeoutExpired:
            logger.error(f"Simulation timed out ({timeout}s)")
            return {"success": False, "error": f"Simulation timed out after {timeout}s"}
        except Exception as e:
            logger.error(f"Simulation error: {e}")
            return {"success": False, "error": str(e)}

    def synthesize(self, rtl_files: list, top_module: str = "rv32i_core",
                   tech_lib: str = None) -> dict:
        """
        Run logic synthesis with yosys.

        Args:
            rtl_files: List of paths to Verilog source files
            top_module: Name of the top-level module
            tech_lib: Optional path to technology library

        Returns:
            Dict with synthesis results, report, and netlist
        """
        timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
        log_file = os.path.join(self.log_dir, "synthesis", f"synthesize_{timestamp}.log")
        report_file = os.path.join(self.log_dir, "synthesis", f"report_{timestamp}.txt")
        netlist_file = os.path.join(self.output_dir, "netlist", f"{top_module}_netlist.v")
        stat_file = os.path.join(self.log_dir, "synthesis", f"stats_{timestamp}.json")

        # Write yosys script
        yosys_script = os.path.join(self.log_dir, "synthesis", f"yosys_script_{timestamp}.ys")
        with open(yosys_script, "w", encoding="utf-8") as f:
            # Read all RTL files with -sv flag for SystemVerilog support
            for rtl in rtl_files:
                if os.path.exists(rtl):
                    f.write(f"read_verilog -sv {rtl}\n")
                else:
                    logger.warning(f"Skipping missing RTL: {rtl}")

            f.write(f"hierarchy -check -top {top_module}\n")
            f.write("proc\n")
            f.write("flatten\n")
            f.write("opt\n")
            f.write("fsm\n")
            f.write("opt\n")
            f.write(f"tee -o {report_file} stat\n")
            f.write(f"write_verilog -noattr {netlist_file}\n")

        logger.info(f"Running synthesis for {top_module}...")
        logger.debug(f"Yosys script: {yosys_script}")

        try:
            result = subprocess.run(
                [self.yosys, "-s", yosys_script],
                capture_output=True,
                text=True,
                timeout=600,
            )

            with open(log_file, "w", encoding="utf-8") as f:
                f.write(f"=== Synthesis Log ===\n")
                f.write(f"Timestamp: {datetime.now().isoformat()}\n")
                f.write(f"Top module: {top_module}\n")
                f.write(f"=== STDOUT ===\n{result.stdout}\n")
                f.write(f"=== STDERR ===\n{result.stderr}\n")
                f.write(f"=== Return Code: {result.returncode} ===\n")

            success = result.returncode == 0
            netlist_exists = os.path.exists(netlist_file)

            # Extract statistics
            stats = self._parse_yosys_stats(result.stdout)

            # Save stats as JSON
            import json
            with open(stat_file, "w", encoding="utf-8") as f:
                json.dump(stats, f, indent=2)

            if success and netlist_exists:
                logger.info(f"Synthesis successful. Netlist: {netlist_file}")
                logger.info(f"Stats: cells={stats.get('cells', '?')}, area={stats.get('area', '?')}")
            else:
                logger.error(f"Synthesis failed (code {result.returncode})")

            return {
                "success": success and netlist_exists,
                "log_file": log_file,
                "report_file": report_file,
                "netlist_file": netlist_file if netlist_exists else None,
                "stats": stats,
                "stdout": result.stdout,
                "stderr": result.stderr,
            }

        except subprocess.TimeoutExpired:
            logger.error("Synthesis timed out (600s)")
            return {"success": False, "error": "Synthesis timed out"}
        except Exception as e:
            logger.error(f"Synthesis error: {e}")
            return {"success": False, "error": str(e)}

    def generate_synthesis_report(self, synthesis_result: dict) -> str:
        """Generate a human-readable synthesis report."""
        stats = synthesis_result.get("stats", {})
        report_path = os.path.join(self.log_dir, "synthesis", "synthesis_summary.txt")

        lines = []
        lines.append("=" * 60)
        lines.append("  VeriGraph Synthesis Report — RV32I Core")
        lines.append("=" * 60)
        lines.append(f"  Generated: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")
        lines.append(f"  Status: {'SUCCESS' if synthesis_result.get('success') else 'FAILED'}")
        lines.append("-" * 60)
        lines.append("  Cell Statistics:")
        lines.append(f"    Total Cells:     {stats.get('cells', 'N/A')}")
        lines.append(f"    Combinational:   {stats.get('combinational', 'N/A')}")
        lines.append(f"    Sequential:      {stats.get('sequential', 'N/A')}")
        lines.append(f"    Wires:           {stats.get('wires', 'N/A')}")
        if stats.get('area'):
            lines.append(f"    Estimated Area:  {stats.get('area', 'N/A')}")
        lines.append("-" * 60)
        lines.append("  Memory Usage:")
        lines.append(f"    Registers:       {stats.get('registers', 'N/A')}")
        lines.append(f"    MUX:             {stats.get('mux', 'N/A')}")
        lines.append("-" * 60)
        lines.append(f"  Netlist: {synthesis_result.get('netlist_file', 'N/A')}")
        lines.append(f"  Report:  {synthesis_result.get('report_file', 'N/A')}")
        lines.append(f"  Log:     {synthesis_result.get('log_file', 'N/A')}")
        lines.append("=" * 60)

        report = "\n".join(lines)
        with open(report_path, "w", encoding="utf-8") as f:
            f.write(report)

        logger.info(f"Synthesis report saved: {report_path}")
        return report_path

    # ---- Error/Warning Parsing ----

    @staticmethod
    def _parse_iverilog_errors(output: str) -> list:
        """Extract error messages from iverilog output."""
        errors = []
        for line in output.split("\n"):
            if "error" in line.lower():
                errors.append(line.strip())
            elif ":syntax error" in line.lower():
                errors.append(line.strip())
        return errors

    @staticmethod
    def _parse_iverilog_warnings(output: str) -> list:
        """Extract warning messages from iverilog output."""
        warnings = []
        for line in output.split("\n"):
            if "warning" in line.lower():
                warnings.append(line.strip())
        return warnings

    @staticmethod
    def _parse_yosys_stats(output: str) -> dict:
        """Parse yosys stat output into structured data."""
        stats = {}
        # Look for the stat output
        lines = output.split("\n")
        in_stats = False
        for line in lines:
            line = line.strip()
            if "Chip area for top module" in line or "Number of cells" in line:
                in_stats = True

            if in_stats:
                # Number of cells: ...
                m = re.match(r"Number of cells:\s+(\d+)", line)
                if m:
                    stats["cells"] = int(m.group(1))
                    continue

                m = re.match(r"Number of wires:\s+(\d+)", line)
                if m:
                    stats["wires"] = int(m.group(1))
                    continue

                if "Chip area" in line and "top module" in line:
                    continue

                # \$_AND_      123
                m = re.match(r"\s+(\S+)\s+(\d+)", line)
                if m:
                    cell_type = m.group(1)
                    if "DFF" in cell_type or "DLATCH" in cell_type or "DLATCH" in cell_type:
                        stats["sequential"] = stats.get("sequential", 0) + int(m.group(2))
                        stats["registers"] = stats.get("registers", 0) + int(m.group(2))
                    elif "MUX" in cell_type:
                        stats["mux"] = stats.get("mux", 0) + int(m.group(2))
                    else:
                        stats["combinational"] = stats.get("combinational", 0) + int(m.group(2))

        return stats


def run_quick_syntax_check(rtl_file: str, iverilog_path: str = "iverilog") -> dict:
    """Quick syntax check on a single RTL file."""
    try:
        result = subprocess.run(
            [iverilog_path, "-g2012", "-tnull", rtl_file],
            capture_output=True,
            text=True,
            timeout=30,
        )
        return {
            "success": result.returncode == 0,
            "file": rtl_file,
            "stderr": result.stderr,
        }
    except Exception as e:
        return {"success": False, "file": rtl_file, "error": str(e)}


def syntax_check_with_deps(
    module_file: str,
    dep_files: list,
    iverilog_path: str = "iverilog",
) -> dict:
    """
    Syntax check a module together with its dependency files.
    This catches issues like:
    - Embedded module definitions causing duplicates
    - Port mismatches against dependencies
    - Missing dependency modules
    """
    all_files = [module_file] + [f for f in dep_files if f and os.path.exists(f)]
    try:
        result = subprocess.run(
            [iverilog_path, "-g2012", "-tnull"] + all_files,
            capture_output=True,
            text=True,
            timeout=30,
        )
        errors = _parse_iverilog_errors_static(result.stderr)
        # Filter to only errors in the module file itself
        module_errors = [e for e in errors if os.path.basename(module_file) in e]
        return {
            "success": result.returncode == 0,
            "file": module_file,
            "stderr": result.stderr,
            "errors": errors,
            "module_errors": module_errors,
        }
    except Exception as e:
        return {"success": False, "file": module_file, "error": str(e)}


def _parse_iverilog_errors_static(output: str) -> list:
    """Extract error messages from iverilog output (static method)."""
    errors = []
    for line in output.split("\n"):
        if "error" in line.lower() or "syntax error" in line.lower():
            errors.append(line.strip())
    return errors


def parse_errors_by_module(stderr: str) -> dict:
    """
    Parse iverilog/yosys stderr and group errors by module name.
    Returns {module_name: [error_lines]}.
    """
    import re
    module_errors = {}
    current_module = None

    for line in stderr.split("\n"):
        line = line.strip()
        if not line:
            continue

        # Try to extract module name from file path
        m = re.search(r'modules/(\w+)/(\w+)\.v', line)
        if m:
            current_module = m.group(1)
            if current_module not in module_errors:
                module_errors[current_module] = []
            module_errors[current_module].append(line)
        elif current_module and ("error" in line.lower() or "syntax" in line.lower()):
            module_errors[current_module].append(line)

    return module_errors
