"""
CrewAI Agent definitions for VeriGraph multi-agent RTL generation system.

Agents:
1. Spec Analyst — Parses hardware specification into structured data
2. RTL Designer — Generates Verilog RTL code from specifications
3. Testbench Generator — Creates testbenches for verification
4. Code Reviewer — Reviews generated RTL for correctness and conventions
5. Integration Architect — Handles top-level integration and wiring
"""

from crewai import Agent
from crewai import LLM
from typing import Optional


def create_llm(
    model: str = "MiniMax-M2.7",
    api_key: str = None,
    base_url: str = None,
    temperature: float = 0.7,
    max_tokens: int = 128000,
    timeout: int = 3600,
) -> LLM:
    """
    Create an LLM instance for CrewAI agents.

    MiniMax uses an OpenAI-compatible API at https://api.minimax.chat/v1
    """
    import os

    api_key = api_key or os.environ.get("DEEPSEEK_API_KEY", "")
    print(api_key)
    base_url = base_url or "https://api.deepseek.com"

    return LLM(
        model=f"openai/{model}",
        api_key=api_key,
        base_url=base_url,
        temperature=temperature,
        max_tokens=max_tokens,
        timeout=timeout,
    )


def create_spec_analyst(llm: LLM) -> Agent:
    """
    Spec Analyst Agent:
    Analyzes hardware specifications and extracts structured module requirements.
    Produces JSON specification that downstream agents can process.
    """
    return Agent(
        role="Hardware Specification Analyst",
        goal="Parse and extract structured module specifications from the RV32I core design document. "
             "Identify all modules, their ports, functionality, and interconnections.",
        backstory=(
            "You are a senior hardware architect with 20 years of experience in RISC-V processor design. "
            "You excel at reading hardware specifications and breaking them down into precise, "
            "structured module descriptions. Your analysis forms the foundation for RTL generation."
        ),
        llm=llm,
        verbose=True,
        allow_delegation=False,
        max_iter=3,
    )


def create_rtl_designer(llm: LLM) -> Agent:
    """
    RTL Designer Agent:
    Generates synthesizable SystemVerilog/Verilog RTL code from module specifications.
    Follows industry best practices for coding style, naming conventions, and synthesis compatibility.
    """
    return Agent(
        role="Senior RTL Design Engineer",
        goal="Generate clean, synthesizable Verilog RTL code for the specified module. "
             "Ensure the code follows all coding conventions, handles all edge cases, "
             "and matches the exact port interface specified.",
        backstory=(
            "You are a senior RTL design engineer specializing in RISC-V microarchitecture. "
            "You have implemented dozens of processor cores and are an expert in writing "
            "clean, synthesizable Verilog that passes lint, simulation, and synthesis. "
            "You always use non-blocking assignments (<=) in sequential blocks, "
            "blocking assignments (=) in combinational blocks, and follow a consistent naming convention. "
            "You handle resets properly (synchronous or asynchronous as specified)."
        ),
        llm=llm,
        verbose=True,
        allow_delegation=False,
        max_iter=3,
    )


def create_testbench_generator(llm: LLM) -> Agent:
    """
    Testbench Generator Agent:
    Creates comprehensive Verilog testbenches with stimulus generation,
    result checking, and VCD waveform dumping.
    """
    return Agent(
        role="Verification Engineer",
        goal="Create comprehensive, self-checking Verilog testbenches that verify "
             "all functional paths of the module under test. Generate VCD waveforms for debugging.",
        backstory=(
            "You are a verification engineer with expertise in UVM and directed testing. "
            "You create testbenches that are thorough, self-checking, and produce clear pass/fail results. "
            "Every testbench includes $dumpfile and $dumpvars for waveform generation, "
            "multiple test cases covering normal operations and edge cases, "
            "and clear status messages."
        ),
        llm=llm,
        verbose=True,
        allow_delegation=False,
        max_iter=3,
    )


def create_code_reviewer(llm: LLM) -> Agent:
    """
    Code Reviewer Agent:
    Reviews generated RTL for correctness, synthesis compatibility,
    coding style adherence, and potential bugs.
    """
    return Agent(
        role="RTL Code Reviewer",
        goal="Review generated Verilog code for correctness, identify potential bugs, "
             "synthesis issues, and ensure adherence to coding standards. "
             "Provide specific, actionable feedback in JSON format.",
        backstory=(
            "You are a meticulous code reviewer who has reviewed thousands of RTL designs. "
            "You catch subtle bugs like missing signal assignments, incomplete case statements, "
            "latch inference, multiple drivers, and improper reset handling. "
            "You provide clear, structured feedback with severity levels and fix suggestions."
        ),
        llm=llm,
        verbose=True,
        allow_delegation=False,
        max_iter=2,
    )


def create_integration_architect(llm: LLM) -> Agent:
    """
    Integration Architect Agent:
    Designs the top-level wrapper that instantiates and connects all submodules.
    Ensures correct signal connectivity and proper module parameterization.
    """
    return Agent(
        role="SoC Integration Architect",
        goal="Create the top-level RV32I core wrapper module that correctly instantiates "
             "and connects all 15 submodules. Ensure all signal connections match the "
             "module interfaces exactly.",
        backstory=(
            "You are an SoC integration architect who specializes in assembling complex "
            "processor cores from individual modules. You meticulously verify every signal "
            "connection, ensure consistent naming conventions, and create clean, "
            "well-organized top-level wrappers."
        ),
        llm=llm,
        verbose=True,
        allow_delegation=False,
        max_iter=3,
    )


def get_all_agents(llm: LLM) -> dict:
    """Create and return all agents."""
    return {
        "spec_analyst": create_spec_analyst(llm),
        "rtl_designer": create_rtl_designer(llm),
        "testbench_generator": create_testbench_generator(llm),
        "code_reviewer": create_code_reviewer(llm),
        "integration_architect": create_integration_architect(llm),
    }
