from typing import List, Dict, Any, Optional
from pydantic import BaseModel, Field
from enum import Enum


class NodeType(str, Enum):
    MODULE = "module"
    INTERFACE = "interface"
    PIPELINE_STAGE = "pipeline_stage"
    EXECUTION_UNIT = "execution_unit"
    REGISTER_FILE = "register_file"
    CACHE = "cache"
    CONTROL_UNIT = "control_unit"
    SYSTEM = "system"
    UNKNOWN = "unknown"


class EdgeType(str, Enum):
    CONNECTS = "connects"
    DEPENDS_ON = "depends_on"
    CONTAINS = "contains"
    SIGNALS = "signals"


def safe_node_type(value: str) -> NodeType:
    try:
        return NodeType(value)
    except ValueError:
        return NodeType.MODULE


def safe_edge_type(value: str) -> EdgeType:
    try:
        return EdgeType(value)
    except ValueError:
        return EdgeType.CONNECTS


class Port(BaseModel):
    name: str
    direction: str
    width: int
    type: str = "logic"


class InterfaceSignal(BaseModel):
    name: str
    direction: str
    width: int
    description: str = ""


class ModuleNode(BaseModel):
    id: str
    name: str
    node_type: NodeType
    description: str = ""
    ports: List[Port] = Field(default_factory=list)
    parameters: Dict[str, Any] = Field(default_factory=dict)
    implementation: Optional[str] = None
    sub_modules: List[str] = Field(default_factory=list)
    interfaces: List[str] = Field(default_factory=list)
    properties: Dict[str, Any] = Field(default_factory=dict)


class Edge(BaseModel):
    source: str
    target: str
    edge_type: EdgeType
    label: str = ""
    properties: Dict[str, Any] = Field(default_factory=dict)


class KnowledgeGraph(BaseModel):
    nodes: Dict[str, ModuleNode] = Field(default_factory=dict)
    edges: List[Edge] = Field(default_factory=list)

    def add_node(self, node: ModuleNode):
        self.nodes[node.id] = node

    def add_edge(self, edge: Edge):
        self.edges.append(edge)

    def get_nodes_by_type(self, node_type: NodeType) -> List[ModuleNode]:
        return [n for n in self.nodes.values() if n.node_type == node_type]

    def get_dependencies(self, node_id: str) -> List[str]:
        return [e.target for e in self.edges if e.source == node_id]


class ImplementationPlan(BaseModel):
    phases: List[Dict[str, Any]] = Field(default_factory=list)
    module_order: List[str] = Field(default_factory=list)
    dependencies: Dict[str, List[str]] = Field(default_factory=dict)
    milestones: Dict[str, str] = Field(default_factory=dict)


class RTLModule(BaseModel):
    name: str
    file_path: str
    content: str
    dependencies: List[str] = Field(default_factory=list)
    verification_status: str = "pending"
    syntax_errors: List[str] = Field(default_factory=list)


class HDAGraph(BaseModel):
    knowledge_graph: KnowledgeGraph
    implementation_plan: ImplementationPlan
    rtl_modules: Dict[str, RTLModule] = Field(default_factory=dict)
    metadata: Dict[str, Any] = Field(default_factory=dict)

    def get_topological_order(self) -> List[str]:
        visited = set()
        order = []

        def visit(node_id: str):
            if node_id in visited:
                return
            visited.add(node_id)
            for dep in self.implementation_plan.dependencies.get(node_id, []):
                visit(dep)
            order.append(node_id)

        for node_id in self.implementation_plan.module_order:
            visit(node_id)
        return order


class SpecDocument(BaseModel):
    title: str = ""
    version: str = ""
    architecture: str = ""
    content: str = ""
    sections: Dict[str, str] = Field(default_factory=dict)


class AgentResult(BaseModel):
    agent_name: str
    success: bool
    output: Any
    errors: List[str] = Field(default_factory=list)
    metadata: Dict[str, Any] = Field(default_factory=dict)
