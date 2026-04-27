import os
import json
import time
from typing import Any, Dict, Optional, List
from abc import ABC, abstractmethod
import requests

try:
    from openai import OpenAI
    OPENAI_AVAILABLE = True
except ImportError:
    OPENAI_AVAILABLE = False

try:
    import anthropic
    ANTHROPIC_AVAILABLE = True
except ImportError:
    ANTHROPIC_AVAILABLE = False


class LLMClient:
    def __init__(self, provider: str = "minimax", api_key: Optional[str] = None,
                 model: str = "MiniMax-M2.7", base_url: Optional[str] = None):
        self.provider = provider
        self.api_key = api_key or os.environ.get("MINIMAX_API_KEY") or os.environ.get("OPENAI_API_KEY")
        print(self.api_key)
        self.model = model
        self.base_url = base_url

    def generate(self, prompt: str, temperature: float = 0.7, max_tokens: int = 128000) -> str:
        if self.provider == "minimax":
            return self._generate_minimax(prompt, temperature, max_tokens)
        elif self.provider == "openai":
            return self._generate_openai(prompt, temperature, max_tokens)
        elif self.provider == "anthropic":
            return self._generate_anthropic(prompt, temperature, max_tokens)
        else:
            raise ValueError(f"Unknown provider: {self.provider}")

    def _generate_minimax(self, prompt: str, temperature: float, max_tokens: int) -> str:
        if not OPENAI_AVAILABLE:
            raise ImportError("openai package not installed. Run: pip install openai")

        client = OpenAI(api_key=self.api_key, base_url="https://api.minimax.chat/v1")
        response = client.chat.completions.create(
            model="MiniMax-M2.7",
            messages=[
                {"role": "system", "content": "You are an expert RTL hardware design assistant."},
                {"role": "user", "content": prompt}
            ],
            temperature=temperature,
            max_tokens=max_tokens,
            extra_body={
                "reasoning_split": True,
                "reply_constraints": {
                    "sender_type": "bot"
                }
            }
        )
        return response.choices[0].message.content or ""

    def _generate_openai(self, prompt: str, temperature: float, max_tokens: int) -> str:
        if not OPENAI_AVAILABLE:
            raise ImportError("openai package not installed")
        client = OpenAI(api_key=self.api_key, base_url=self.base_url)
        response = client.chat.completions.create(
            model=self.model,
            messages=[{"role": "user", "content": prompt}],
            temperature=temperature,
            max_tokens=max_tokens
        )
        return response.choices[0].message.content

    def _generate_anthropic(self, prompt: str, temperature: float, max_tokens: int) -> str:
        if not ANTHROPIC_AVAILABLE:
            raise ImportError("anthropic package not installed")
        client = anthropic.Anthropic(api_key=self.api_key)
        response = client.messages.create(
            model=self.model,
            max_tokens=max_tokens,
            messages=[{"role": "user", "content": prompt}]
        )
        return response.content[0].text


class BaseAgent(ABC):
    def __init__(self, name: str, role: str, goal: str, llm_client: LLMClient,
                 backstory: str = "", tools: Optional[List[Any]] = None):
        self.name = name
        self.role = role
        self.goal = goal
        self.llm_client = llm_client
        self.backstory = backstory
        self.tools = tools or []
        self.history: List[Dict[str, str]] = []

    @abstractmethod
    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        pass

    def prompt(self, template: str, **kwargs) -> str:
        return template.format(**kwargs)

    def think(self, task: str) -> str:
        prompt = self._build_prompt(task)
        response = self.llm_client.generate(prompt)
        self.history.append({"task": task, "response": response})
        cleaned = self._clean_response(response)
        return cleaned

    def _clean_response(self, response: str) -> str:
        import re
        match = re.search(r'```(?:json)?\s*(.*?)\s*```', response, re.DOTALL)
        if match:
            return match.group(1).strip()
        if response.strip().startswith('{') or response.strip().startswith('['):
            return response.strip()
        return response

    def _build_prompt(self, task: str) -> str:
        return f"""You are a {self.role}.
{self.backstory}

Your goal: {self.goal}

Task: {task}

Remember to focus on {self.goal}.
"""

    def __repr__(self):
        return f"{self.__class__.__name__}(name={self.name}, role={self.role})"


class SequentialAgent(BaseAgent):
    def __init__(self, agents: List[BaseAgent], **kwargs):
        super().__init__(
            name="SequentialCoordinator",
            role="Sequential Coordinator",
            goal="Coordinate sequential execution of sub-agents",
            **kwargs
        )
        self.agents = agents

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        results = {}
        current_context = context.copy()

        for agent in self.agents:
            result = agent.execute(current_context)
            results[agent.name] = result
            current_context.update(result)

        return {"results": results, "final_context": current_context}


class ParallelAgent(BaseAgent):
    def __init__(self, agents: List[BaseAgent], **kwargs):
        super().__init__(
            name="ParallelCoordinator",
            role="Parallel Coordinator",
            goal="Coordinate parallel execution of sub-agents",
            **kwargs
        )
        self.agents = agents

    def execute(self, context: Dict[str, Any]) -> Dict[str, Any]:
        results = {}
        for agent in self.agents:
            result = agent.execute(context)
            results[agent.name] = result
        return {"results": results, "context": context}
