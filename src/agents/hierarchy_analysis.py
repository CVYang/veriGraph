from typing import Dict, Any, List, Set
import json
from .base import BaseAgent, LLMClient
from ..core.models import KnowledgeGraph, ModuleNode, Edge, NodeType, EdgeType, ImplementationPlan


class KnowledgeGraphBuilder(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="KGBBuilder",
            role="Knowledge Graph Builder",
            goal="Construct a hierarchical knowledge graph encoding module relationships",
            backstory="""You are an expert at building knowledge graphs that represent
            complex system architectures. You understand how to encode parent-child
            relationships, interface connections, and dependency hierarchies.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        modules = context.get("modules", [])
        summary = context.get("summary", {})
        if not modules:
            return {"success": False, "error": "No modules provided"}

        prompt = f"""Build a hierarchical knowledge graph for this RISC-V processor.

MODULES:
{json.dumps(modules, indent=2)}

ARCHITECTURE SUMMARY:
{json.dumps(summary, indent=2)}

Create:
1. **Nodes**: Each module as a node with type, properties, interfaces
2. **Edges**: Relationships between modules (contains, connects, depends_on)
3. **Hierarchy**: Parent-child relationships (e.g., Core contains ALU, FPU, etc.)
4. **Interface Mapping**: How modules connect to each other

For each node, specify:
- id: unique identifier
- name: module name
- node_type: module, interface, pipeline_stage, execution_unit, register_file, cache, control_unit
- description: what it does
- interfaces: list of interface names
- properties: key parameters (width, depth, latency, etc.)

For each edge:
- source: parent module id
- target: child/connected module id
- edge_type: contains, connects, depends_on
- label: relationship description

Output format (JSON):
{{
    "nodes": [
        {{
            "id": "unique_id",
            "name": "module_name",
            "node_type": "module",
            "description": "",
            "interfaces": ["interface1"],
            "properties": {{"param": "value"}}
        }}
    ],
    "edges": [
        {{
            "source": "parent_id",
            "target": "child_id",
            "edge_type": "contains",
            "label": ""
        }}
    ]
}}
"""
        response = self.think(prompt)
        try:
            kg_data = json.loads(response)
            kg = self._build_graph(kg_data)
            return {"success": True, "knowledge_graph": kg}
        except json.JSONDecodeError:
            return {"success": False, "error": "Failed to parse JSON", "raw_response": response}

    def _build_graph(self, kg_data: Dict[str, Any]) -> KnowledgeGraph:
        kg = KnowledgeGraph()

        for node_data in kg_data.get("nodes", []):
            from ..core.models import safe_node_type
            node = ModuleNode(
                id=node_data["id"],
                name=node_data["name"],
                node_type=safe_node_type(node_data.get("node_type", "module")),
                description=node_data.get("description", ""),
                interfaces=node_data.get("interfaces", []),
                properties=node_data.get("properties", {})
            )
            kg.add_node(node)

        for edge_data in kg_data.get("edges", []):
            from ..core.models import safe_edge_type
            edge = Edge(
                source=edge_data["source"],
                target=edge_data["target"],
                edge_type=safe_edge_type(edge_data.get("edge_type", "connects")),
                label=edge_data.get("label", "")
            )
            kg.add_edge(edge)

        return kg


class HierarchyAnalyzer(BaseAgent):
    def __init__(self, llm_client: LLMClient):
        super().__init__(
            name="HierarchyAnalyzer",
            role="Module Hierarchy Analyzer",
            goal="Analyze module hierarchy and determine implementation order",
            backstory="""You are an expert at analyzing module hierarchies and determining
            the correct implementation order for complex systems. You understand
            dependencies and know how to schedule independent modules for parallel development.""",
            llm_client=llm_client
        )

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        kg_data = context.get("knowledge_graph_data", {})
        modules = context.get("modules", [])
        if not kg_data and not modules:
            return {"success": False, "error": "No graph data provided"}

        prompt = f"""Analyze the module hierarchy and create an implementation plan.

MODULES:
{json.dumps(modules, indent=2)}

KNOWLEDGE GRAPH DATA:
{json.dumps(kg_data, indent=2)}

Determine:
1. **Topological Order**: Which modules depend on which others
2. **Parallelization Opportunities**: Which modules can be implemented in parallel
3. **Phases**: Group modules into implementation phases
4. **Critical Path**: Modules that are on the critical path

For each phase specify:
- Phase name and description
- List of modules to implement
- Expected duration/complexity
- Prerequisites (which phases must complete first)

Output format (JSON):
{{
    "module_order": ["module1", "module2", ...],
    "dependencies": {{
        "module1": ["module0"],
        "module2": ["module1"]
    }},
    "phases": [
        {{
            "name": "Phase 1: Foundation",
            "description": "",
            "modules": ["module1", "module2"],
            "prerequisites": [],
            "parallelizable": true
        }}
    ],
    "milestones": {{
        "phase1_complete": "Foundation modules ready"
    }}
}}
"""
        response = self.think(prompt)
        try:
            plan_data = json.loads(response)
            plan = ImplementationPlan(
                phases=plan_data.get("phases", []),
                module_order=plan_data.get("module_order", []),
                dependencies=plan_data.get("dependencies", {}),
                milestones=plan_data.get("milestones", {})
            )
            return {"success": True, "implementation_plan": plan, "plan_data": plan_data}
        except json.JSONDecodeError:
            return {"success": False, "error": "Failed to parse JSON", "raw_response": response}


class HierarchyAnalysisPipeline:
    def __init__(self, llm_client: LLMClient):
        self.kg_builder = KnowledgeGraphBuilder(llm_client)
        self.hierarchy_analyzer = HierarchyAnalyzer(llm_client)

    def run(self, context: Dict[str, Any]) -> Dict[str, Any]:
        kg_result = self.kg_builder.execute(context)
        if not kg_result.get("success"):
            return kg_result

        kg = kg_result["knowledge_graph"]
        kg_context = {
            **context,
            "knowledge_graph_data": {
                "nodes": [
                    {"id": n.id, "name": n.name, "node_type": n.node_type.value,
                     "description": n.description, "interfaces": n.interfaces,
                     "properties": n.properties}
                    for n in kg.nodes.values()
                ],
                "edges": [
                    {"source": e.source, "target": e.target, "edge_type": e.edge_type.value, "label": e.label}
                    for e in kg.edges
                ]
            }
        }

        plan_result = self.hierarchy_analyzer.execute(kg_context)
        if not plan_result.get("success"):
            return plan_result

        return {
            "success": True,
            "knowledge_graph": kg,
            "implementation_plan": plan_result["implementation_plan"],
            "phases": plan_result.get("plan_data", {}).get("phases", [])
        }
