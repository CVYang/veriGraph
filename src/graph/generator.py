"""
Generate SVG-based HTML knowledge graph showing module relationships,
pipeline structure, and dependencies for the RV32I core.
"""

import os
import json
import logging
from datetime import datetime
from typing import Optional

logger = logging.getLogger(__name__)


# Module metadata for the knowledge graph
MODULE_SPECS = {
    "rv32i_core": {
        "category": "Top-Level",
        "description": "Top-level wrapper instantiating all submodules",
        "color": "#E74C3C",
        "shape": "box3d",
    },
    "if_stage": {
        "category": "Pipeline Stage",
        "description": "Instruction fetch - PC generation and IMEM access",
        "color": "#3498DB",
        "shape": "box",
    },
    "id_stage": {
        "category": "Pipeline Stage",
        "description": "Instruction decode, register read, immediate generation",
        "color": "#2ECC71",
        "shape": "box",
    },
    "ex_stage": {
        "category": "Pipeline Stage",
        "description": "ALU execution and branch resolution",
        "color": "#F39C12",
        "shape": "box",
    },
    "mem_stage": {
        "category": "Pipeline Stage",
        "description": "Load/store memory access via DMEM",
        "color": "#9B59B6",
        "shape": "box",
    },
    "wb_stage": {
        "category": "Pipeline Stage",
        "description": "Write-back results to register file",
        "color": "#1ABC9C",
        "shape": "box",
    },
    "alu": {
        "category": "Functional Unit",
        "description": "Arithmetic Logic Unit (10 RV32I operations)",
        "color": "#E67E22",
        "shape": "component",
    },
    "imm_gen": {
        "category": "Functional Unit",
        "description": "Immediate generator (I/S/B/U/J types)",
        "color": "#E67E22",
        "shape": "component",
    },
    "control_unit": {
        "category": "Functional Unit",
        "description": "Main instruction decoder",
        "color": "#E67E22",
        "shape": "component",
    },
    "reg_file": {
        "category": "Functional Unit",
        "description": "32x32-bit register file (x0=0)",
        "color": "#E67E22",
        "shape": "component",
    },
    "hazard_unit": {
        "category": "Control",
        "description": "Hazard detection, forwarding, stall/flush",
        "color": "#C0392B",
        "shape": "component",
    },
    "if_id_reg": {
        "category": "Pipeline Register",
        "description": "IF/ID pipeline register",
        "color": "#95A5A6",
        "shape": "parallelogram",
    },
    "id_ex_reg": {
        "category": "Pipeline Register",
        "description": "ID/EX pipeline register",
        "color": "#95A5A6",
        "shape": "parallelogram",
    },
    "ex_mem_reg": {
        "category": "Pipeline Register",
        "description": "EX/MEM pipeline register",
        "color": "#95A5A6",
        "shape": "parallelogram",
    },
    "mem_wb_reg": {
        "category": "Pipeline Register",
        "description": "MEM/WB pipeline register",
        "color": "#95A5A6",
        "shape": "parallelogram",
    },
}

PIPELINE_FLOW = [
    ("if_stage", "if_id_reg"),
    ("if_id_reg", "id_stage"),
    ("id_stage", "id_ex_reg"),
    ("id_ex_reg", "ex_stage"),
    ("ex_stage", "ex_mem_reg"),
    ("ex_mem_reg", "mem_stage"),
    ("mem_stage", "mem_wb_reg"),
    ("mem_wb_reg", "wb_stage"),
]

DEPENDENCY_EDGES = [
    ("id_stage", "control_unit", "uses"),
    ("id_stage", "imm_gen", "uses"),
    ("id_stage", "reg_file", "reads"),
    ("ex_stage", "alu", "uses"),
    ("wb_stage", "reg_file", "writes"),
    ("hazard_unit", "if_stage", "stall/flush"),
    ("hazard_unit", "id_stage", "stall/flush"),
    ("hazard_unit", "ex_stage", "forwarding"),
    ("rv32i_core", "if_stage", "instantiates"),
    ("rv32i_core", "id_stage", "instantiates"),
    ("rv32i_core", "ex_stage", "instantiates"),
    ("rv32i_core", "mem_stage", "instantiates"),
    ("rv32i_core", "wb_stage", "instantiates"),
    ("rv32i_core", "alu", "instantiates"),
    ("rv32i_core", "imm_gen", "instantiates"),
    ("rv32i_core", "control_unit", "instantiates"),
    ("rv32i_core", "reg_file", "instantiates"),
    ("rv32i_core", "hazard_unit", "instantiates"),
    ("rv32i_core", "if_id_reg", "instantiates"),
    ("rv32i_core", "id_ex_reg", "instantiates"),
    ("rv32i_core", "ex_mem_reg", "instantiates"),
    ("rv32i_core", "mem_wb_reg", "instantiates"),
]


class KnowledgeGraphGenerator:
    """Generates SVG-based HTML knowledge graph for the RV32I core."""

    def __init__(self, output_dir: str = "./knowledge_graph"):
        self.output_dir = output_dir
        os.makedirs(output_dir, exist_ok=True)

    def generate(self, module_status: dict = None) -> str:
        """
        Generate the complete SVG HTML knowledge graph.

        Args:
            module_status: Dict mapping module name to status ('completed', 'failed', 'pending')

        Returns:
            Path to the generated HTML file
        """
        if module_status is None:
            module_status = {}

        svg_content = self._build_svg(module_status)
        html_content = self._wrap_html(svg_content)

        output_path = os.path.join(self.output_dir, "knowledge_graph.html")
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(html_content)

        logger.info(f"Knowledge graph saved to {output_path}")
        return output_path

    def _build_svg(self, module_status: dict) -> str:
        """Build the SVG content showing pipeline structure and module relationships."""
        # Layout constants
        width = 1400
        height = 1000
        margin = 50
        stage_width = 160
        stage_height = 70
        fu_width = 130
        fu_height = 50

        # Pipeline stages layout (top row)
        stages = ["if_stage", "id_stage", "ex_stage", "mem_stage", "wb_stage"]
        pipeline_regs = ["if_id_reg", "id_ex_reg", "ex_mem_reg", "mem_wb_reg"]
        fus = ["reg_file", "alu", "imm_gen", "control_unit", "hazard_unit"]

        svg_parts = []
        svg_parts.append(f'<svg width="{width}" height="{height}" xmlns="http://www.w3.org/2000/svg">')
        svg_parts.append('<defs>')
        svg_parts.append('<style>')
        svg_parts.append('.node-text { font-family: monospace; font-size: 12px; text-anchor: middle; }')
        svg_parts.append('.node-title { font-family: sans-serif; font-size: 14px; font-weight: bold; text-anchor: middle; }')
        svg_parts.append('.edge-label { font-family: sans-serif; font-size: 9px; fill: #666; text-anchor: middle; }')
        svg_parts.append('.title-text { font-family: sans-serif; font-size: 24px; font-weight: bold; fill: #2C3E50; }')
        svg_parts.append('.subtitle-text { font-family: sans-serif; font-size: 14px; fill: #7F8C8D; }')
        svg_parts.append('</style>')
        # Arrow marker
        svg_parts.append('<marker id="arrow" viewBox="0 0 10 10" refX="10" refY="5" markerWidth="6" markerHeight="6" orient="auto">')
        svg_parts.append('<path d="M0,0 L10,5 L0,10 Z" fill="#555"/>')
        svg_parts.append('</marker>')
        svg_parts.append('<marker id="arrow-blue" viewBox="0 0 10 10" refX="10" refY="5" markerWidth="6" markerHeight="6" orient="auto">')
        svg_parts.append('<path d="M0,0 L10,5 L0,10 Z" fill="#3498DB"/>')
        svg_parts.append('</marker>')
        svg_parts.append('</defs>')

        # Background
        svg_parts.append(f'<rect width="{width}" height="{height}" fill="#FAFAFA" rx="8"/>')

        # Title
        svg_parts.append(f'<text x="{width/2}" y="35" class="title-text">RV32I Single-Issue In-Order Core</text>')
        svg_parts.append(f'<text x="{width/2}" y="58" class="subtitle-text">5-Stage Pipeline Architecture — VeriGraph Knowledge Graph</text>')

        # Legend
        legend_y = 80
        legends = [
            ("Pipeline Stage", "#3498DB"),
            ("Pipeline Register", "#95A5A6"),
            ("Functional Unit", "#E67E22"),
            ("Control Unit", "#C0392B"),
            ("Top-Level", "#E74C3C"),
        ]
        lx = 20
        for label, color in legends:
            svg_parts.append(f'<rect x="{lx}" y="{legend_y}" width="12" height="12" fill="{color}" rx="2"/>')
            svg_parts.append(f'<text x="{lx+16}" y="{legend_y+11}" font-family="sans-serif" font-size="11" fill="#333">{label}</text>')
            lx += 150

        # Pipeline stages row
        stage_start_x = margin + 80
        stage_y = 130
        stage_positions = {}
        x = stage_start_x
        for i, stage in enumerate(stages):
            stage_positions[stage] = (x, stage_y)
            spec = MODULE_SPECS.get(stage, {})
            color = spec.get("color", "#999")
            status = module_status.get(stage, "pending")
            border = self._status_border(status)

            svg_parts.append(f'<rect x="{x}" y="{stage_y}" width="{stage_width}" height="{stage_height}" '
                           f'fill="{color}" rx="6" stroke="{border}" stroke-width="2"/>')
            svg_parts.append(f'<text x="{x + stage_width/2}" y="{stage_y + 28}" class="node-title" fill="white">{stage}</text>')
            svg_parts.append(f'<text x="{x + stage_width/2}" y="{stage_y + 50}" class="node-text" fill="white" font-size="10">{status}</text>')
            x += stage_width + 50

        # Pipeline register nodes (between stages)
        reg_y = stage_y + stage_height + 40
        reg_positions = {}
        for i, reg in enumerate(pipeline_regs):
            rx_pos = stage_start_x + stage_width + 5 + i * (stage_width + 50)
            reg_positions[reg] = (rx_pos, reg_y)
            spec = MODULE_SPECS.get(reg, {})
            color = spec.get("color", "#999")
            status = module_status.get(reg, "pending")
            border = self._status_border(status)

            svg_parts.append(f'<rect x="{rx_pos - 20}" y="{reg_y}" width="80" height="35" '
                           f'fill="{color}" rx="4" stroke="{border}" stroke-width="1.5"/>')
            svg_parts.append(f'<text x="{rx_pos + 20}" y="{reg_y + 14}" font-family="monospace" font-size="8" fill="white" text-anchor="middle">{reg}</text>')
            svg_parts.append(f'<text x="{rx_pos + 20}" y="{reg_y + 28}" font-family="monospace" font-size="7" fill="white" text-anchor="middle">{status}</text>')

        # Pipeline stage → register arrows
        for i, (stage, reg) in enumerate(zip(stages[:-1], pipeline_regs)):
            sx, sy = stage_positions[stage]
            sx += stage_width // 2
            sy += stage_height
            rx, ry = reg_positions[reg]
            ry -= 22 if i % 2 == 0 else 15

            svg_parts.append(f'<line x1="{sx}" y1="{sy}" x2="{sx}" y2="{ry}" '
                           f'stroke="#555" stroke-width="1.5" marker-end="url(#arrow)"/>')

        # Register → next stage arrows
        for i, (reg, stage) in enumerate(zip(pipeline_regs, stages[1:])):
            rx, ry = reg_positions[reg]
            rx += 40
            ry -= 15
            sx2, sy2 = stage_positions[stage]
            sx2 += stage_width // 2
            sy2 += stage_height

            svg_parts.append(f'<line x1="{rx}" y1="{ry}" x2="{rx}" y2="{sy2}" '
                           f'stroke="#555" stroke-width="1.5" marker-end="url(#arrow)"/>')

        # Functional units row
        fu_y = 300
        fu_start_x = stage_start_x
        fu_positions = {}
        for i, fu in enumerate(fus):
            fx = fu_start_x + i * (fu_width + 60) - (20 if i > 0 else 0)
            fu_positions[fu] = (fx, fu_y)
            spec = MODULE_SPECS.get(fu, {})
            color = spec.get("color", "#999")
            status = module_status.get(fu, "pending")
            border = self._status_border(status)

            svg_parts.append(f'<rect x="{fx}" y="{fu_y}" width="{fu_width}" height="{fu_height}" '
                           f'fill="{color}" rx="6" stroke="{border}" stroke-width="1.5"/>')
            svg_parts.append(f'<text x="{fx + fu_width/2}" y="{fu_y + 22}" class="node-text" fill="white" font-size="11">{fu}</text>')
            svg_parts.append(f'<text x="{fx + fu_width/2}" y="{fu_y + 40}" class="node-text" fill="white" font-size="8">{status}</text>')

        # Top-level
        top_y = 400
        top_x = width // 2 - 80
        spec = MODULE_SPECS.get("rv32i_core", {})
        color = spec.get("color", "#E74C3C")
        status = module_status.get("rv32i_core", "pending")
        border = self._status_border(status)

        svg_parts.append(f'<rect x="{top_x}" y="{top_y}" width="160" height="50" '
                       f'fill="{color}" rx="8" stroke="{border}" stroke-width="2.5"/>')
        svg_parts.append(f'<text x="{top_x + 80}" y="{top_y + 22}" class="node-title" fill="white">rv32i_core</text>')
        svg_parts.append(f'<text x="{top_x + 80}" y="{top_y + 40}" class="node-text" fill="white" font-size="9">{status}</text>')

        # Dependency edges (functional units to stages)
        dep_edges = [
            ("id_stage", "control_unit", "decodes"),
            ("id_stage", "imm_gen", "generates"),
            ("id_stage", "reg_file", "reads"),
            ("ex_stage", "alu", "computes"),
            ("wb_stage", "reg_file", "writes"),
            ("hazard_unit", "if_stage", "controls"),
            ("hazard_unit", "id_stage", "controls"),
            ("hazard_unit", "ex_stage", "forwards"),
        ]

        for src_name, dst_name, label in dep_edges:
            if src_name in stage_positions and dst_name in fu_positions:
                sx, sy = stage_positions[src_name]
                fx, fy = fu_positions[dst_name]
                self._draw_dashed_edge(svg_parts, sx, sy, stage_width, stage_height,
                                      fx, fy, fu_width, fu_height, label)

        # Top-level instantiation arrows (simplified)
        top_cx = top_x + 80
        top_cy = top_y + 50
        for stage in stages:
            if stage in stage_positions:
                sx, sy = stage_positions[stage]
                sx += stage_width // 2
                svg_parts.append(f'<line x1="{top_cx}" y1="{top_cy}" x2="{sx}" y2="{sy}" '
                               f'stroke="#E74C3C" stroke-width="0.8" stroke-dasharray="4,3"/>')

        # RV32I instruction table
        inst_y = 480
        svg_parts.append(f'<text x="{width/2}" y="{inst_y}" font-family="sans-serif" font-size="14" font-weight="bold" fill="#2C3E50" text-anchor="middle">RV32I Instruction Categories</text>')

        inst_groups = [
            ("R-Type", ["ADD", "SUB", "AND", "OR", "XOR", "SLL", "SRL", "SRA", "SLT", "SLTU"], "#E74C3C"),
            ("I-Type", ["ADDI", "ANDI", "ORI", "XORI", "SLLI", "SRLI", "SRAI", "SLTI", "SLTIU", "LB", "LH", "LW", "LBU", "LHU", "JALR"], "#3498DB"),
            ("S-Type", ["SB", "SH", "SW"], "#2ECC71"),
            ("B-Type", ["BEQ", "BNE", "BLT", "BGE", "BLTU", "BGEU"], "#F39C12"),
            ("U-Type", ["LUI", "AUIPC"], "#9B59B6"),
            ("J-Type", ["JAL"], "#1ABC9C"),
        ]

        ig_y = inst_y + 18
        for gname, instrs, gcolor in inst_groups:
            svg_parts.append(f'<rect x="{margin}" y="{ig_y}" width="80" height="26" fill="{gcolor}" rx="4"/>')
            svg_parts.append(f'<text x="{margin+40}" y="{ig_y+18}" font-family="sans-serif" font-size="11" font-weight="bold" fill="white" text-anchor="middle">{gname}</text>')
            svg_parts.append(f'<text x="{margin+90}" y="{ig_y+18}" font-family="monospace" font-size="9" fill="#333">{", ".join(instrs)}</text>')
            ig_y += 30

        # Timestamp
        svg_parts.append(f'<text x="{width-20}" y="{height-10}" font-family="sans-serif" font-size="10" fill="#999" text-anchor="end">'
                        f'Generated: {datetime.now().strftime("%Y-%m-%d %H:%M")} | VeriGraph</text>')

        svg_parts.append('</svg>')
        return "\n".join(svg_parts)

    def _status_border(self, status: str) -> str:
        """Get border color based on module status."""
        if status == "completed":
            return "#27AE60"
        elif status == "failed":
            return "#E74C3C"
        elif status == "in_progress":
            return "#F39C12"
        return "#BBB"

    def _draw_dashed_edge(self, svg_parts, sx, sy, sw, sh, ex, ey, ew, eh, label):
        """Draw a dashed dependency edge between two nodes."""
        x1 = sx + sw // 2
        y1 = sy + sh
        x2 = ex + ew // 2
        y2 = ey

        mid_x = (x1 + x2) / 2
        mid_y = (y1 + y2) / 2

        svg_parts.append(f'<path d="M{x1},{y1} C{x1},{mid_y} {x2},{mid_y} {x2},{y2}" '
                       f'stroke="#888" stroke-width="1" stroke-dasharray="5,3" fill="none" marker-end="url(#arrow)"/>')

        if label:
            svg_parts.append(f'<text x="{mid_x}" y="{mid_y - 5}" class="edge-label">{label}</text>')

    def generate_simple_svg(self, module_status: dict = None) -> str:
        """Generate a simpler standalone SVG (without HTML wrapper)."""
        if module_status is None:
            module_status = {}
        svg = self._build_svg(module_status)
        output_path = os.path.join(self.output_dir, "graph.svg")
        with open(output_path, "w", encoding="utf-8") as f:
            f.write(svg)
        logger.info(f"Standalone SVG saved to {output_path}")
        return output_path

    def _wrap_html(self, svg_content: str) -> str:
        """Wrap SVG content in a complete HTML page."""
        return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>VeriGraph — RV32I Core Knowledge Graph</title>
    <style>
        * {{ margin: 0; padding: 0; box-sizing: border-box; }}
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
            background: #ECF0F1;
            display: flex;
            flex-direction: column;
            align-items: center;
            padding: 20px;
        }}
        .container {{
            background: white;
            border-radius: 12px;
            box-shadow: 0 4px 24px rgba(0,0,0,0.1);
            padding: 20px;
            max-width: 1480px;
            width: 100%;
        }}
        .header {{
            text-align: center;
            margin-bottom: 20px;
            padding-bottom: 20px;
            border-bottom: 2px solid #ECF0F1;
        }}
        .header h1 {{ font-size: 28px; color: #2C3E50; margin-bottom: 5px; }}
        .header p {{ color: #7F8C8D; font-size: 14px; }}
        .stats {{
            display: flex;
            justify-content: center;
            gap: 30px;
            margin: 15px 0;
        }}
        .stat {{ text-align: center; }}
        .stat-value {{ font-size: 32px; font-weight: bold; color: #3498DB; }}
        .stat-label {{ font-size: 12px; color: #7F8C8D; text-transform: uppercase; }}
        svg {{ display: block; margin: 0 auto; }}
        .footer {{
            text-align: center;
            margin-top: 20px;
            padding-top: 15px;
            border-top: 1px solid #ECF0F1;
            color: #95A5A6;
            font-size: 12px;
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>VeriGraph — RV32I Core Architecture</h1>
            <p>Multi-Agent RTL Generation Framework | 5-Stage Single-Issue In-Order Pipeline</p>
            <div class="stats">
                <div class="stat">
                    <div class="stat-value">15</div>
                    <div class="stat-label">Verilog Modules</div>
                </div>
                <div class="stat">
                    <div class="stat-value">37</div>
                    <div class="stat-label">RV32I Instructions</div>
                </div>
                <div class="stat">
                    <div class="stat-value">5</div>
                    <div class="stat-label">Pipeline Stages</div>
                </div>
                <div class="stat">
                    <div class="stat-value">4</div>
                    <div class="stat-label">Pipeline Registers</div>
                </div>
            </div>
        </div>
        {svg_content}
        <div class="footer">
            Generated by VeriGraph Multi-Agent RTL Generation Framework | CrewAI-powered | {datetime.now().strftime("%Y-%m-%d %H:%M:%S")}
        </div>
    </div>
</body>
</html>"""

    def generate_module_detail_page(self, module_name: str, rtl_code: str,
                                     spec: dict, module_status: dict = None) -> str:
        """Generate a detail HTML page for a specific module."""
        if module_status is None:
            module_status = {}

        status = module_status.get(module_name, "pending")
        meta = MODULE_SPECS.get(module_name, {})
        category = meta.get("category", "Unknown")
        description = meta.get("description", "")

        html = f"""<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>{module_name} — VeriGraph Module Detail</title>
<style>
*{{margin:0;padding:0;box-sizing:border-box}}
body{{font-family:monospace;background:#1E1E1E;color:#D4D4D4;padding:20px}}
.container{{max-width:1200px;margin:0 auto}}
.header{{background:#252526;padding:20px;border-radius:8px;margin-bottom:20px}}
.header h1{{color:#569CD6;font-size:24px}}
.header .meta{{color:#808080;margin-top:8px;font-size:13px}}
.status{{display:inline-block;padding:3px 10px;border-radius:12px;font-size:12px;margin-left:10px}}
.status.completed{{background:#1B5E20;color:#4CAF50}}
.status.failed{{background:#B71C1C;color:#EF5350}}
.status.pending{{background:#424242;color:#9E9E9E}}
.code-block{{background:#1E1E1E;border:1px solid #333;border-radius:8px;overflow:hidden;margin-bottom:20px}}
.code-header{{background:#2D2D2D;padding:10px 15px;color:#808080;font-size:13px;border-bottom:1px solid #333}}
.code-content{{padding:15px;overflow-x:auto;white-space:pre;font-size:13px;line-height:1.6}}
.nav{{display:flex;gap:10px;margin-bottom:20px}}
.nav a{{color:#569CD6;text-decoration:none;padding:8px 16px;background:#252526;border-radius:4px;font-size:13px}}
.nav a:hover{{background:#333}}
.back{{margin-top:20px}}
.back a{{color:#808080;text-decoration:none;font-size:13px}}
</style></head>
<body>
<div class="container">
<div class="nav">
    <a href="knowledge_graph.html">Graph</a>
    <a href="module_list.html">Module List</a>
</div>
<div class="header">
    <h1>{module_name}<span class="status {status}">{status.upper()}</span></h1>
    <div class="meta">Category: {category} | {description}</div>
</div>
<div class="code-block">
    <div class="code-header">{module_name}.v — {len(rtl_code)} characters</div>
    <div class="code-content">{self._escape_html(rtl_code)}</div>
</div>
<div class="back"><a href="javascript:history.back()">Back</a></div>
</div>
</body></html>"""

        module_dir = os.path.join(self.output_dir, "modules")
        os.makedirs(module_dir, exist_ok=True)
        path = os.path.join(module_dir, f"{module_name}.html")
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        return path

    def generate_module_list_page(self, module_status: dict = None) -> str:
        """Generate an index page listing all modules with links to detail pages."""
        if module_status is None:
            module_status = {}

        rows = ""
        for name, meta in MODULE_SPECS.items():
            status = module_status.get(name, "pending")
            status_class = status
            rows += f"""
            <tr>
                <td><a href="modules/{name}.html">{name}</a></td>
                <td>{meta['category']}</td>
                <td>{meta['description']}</td>
                <td><span class="status {status_class}">{status.upper()}</span></td>
            </tr>"""

        html = f"""<!DOCTYPE html>
<html lang="en">
<head><meta charset="UTF-8"><title>Module List — VeriGraph</title>
<style>
*{{margin:0;padding:0;box-sizing:border-box}}
body{{font-family:monospace;background:#1E1E1E;color:#D4D4D4;padding:20px}}
.container{{max-width:1000px;margin:0 auto}}
h1{{color:#569CD6;margin-bottom:20px}}
table{{width:100%;border-collapse:collapse;background:#252526;border-radius:8px;overflow:hidden}}
th{{background:#333;padding:12px;text-align:left;font-size:13px;color:#808080;text-transform:uppercase}}
td{{padding:12px;border-bottom:1px solid #333;font-size:13px}}
tr:hover{{background:#2D2D2D}}
a{{color:#569CD6;text-decoration:none}}
a:hover{{text-decoration:underline}}
.status{{display:inline-block;padding:3px 10px;border-radius:12px;font-size:11px}}
.status.completed{{background:#1B5E20;color:#4CAF50}}
.status.failed{{background:#B71C1C;color:#EF5350}}
.status.pending{{background:#424242;color:#9E9E9E}}
.nav{{margin-bottom:20px}}
.nav a{{color:#569CD6;text-decoration:none;padding:8px 16px;background:#252526;border-radius:4px;font-size:13px;margin-right:10px}}
</style></head>
<body>
<div class="container">
<div class="nav"><a href="knowledge_graph.html">Knowledge Graph</a></div>
<h1>Module List — RV32I Core</h1>
<table><thead><tr><th>Module</th><th>Category</th><th>Description</th><th>Status</th></tr></thead><tbody>{rows}</tbody></table>
</div></body></html>"""

        path = os.path.join(self.output_dir, "module_list.html")
        with open(path, "w", encoding="utf-8") as f:
            f.write(html)
        return path

    @staticmethod
    def _escape_html(text: str) -> str:
        return text.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")
