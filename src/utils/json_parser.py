"""
Flexible JSON parser for extracting structured data from LLM outputs.
Handles various LLM response formats and attempts multiple extraction strategies.
"""

import json
import re
import logging

logger = logging.getLogger(__name__)


def extract_json(text: str, strategy: str = "auto") -> dict:
    """
    Extract JSON from LLM response text using multiple strategies.

    Args:
        text: Raw LLM response text
        strategy: 'auto', 'code_block', 'json_block', 'brace', 'line'

    Returns:
        Parsed dict, or {'_parse_error': str, '_raw': text} on failure
    """
    if not text or not text.strip():
        return {"_parse_error": "Empty input", "_raw": text}

    original = text
    text = text.strip()

    strategies = []
    if strategy == "auto":
        strategies = ["code_block", "json_block", "brace", "line"]
    elif strategy == "code_block":
        strategies = ["code_block"]
    elif strategy == "json_block":
        strategies = ["json_block"]
    elif strategy == "brace":
        strategies = ["brace"]
    elif strategy == "line":
        strategies = ["line"]
    else:
        strategies = [strategy]

    errors = []

    for strat in strategies:
        try:
            if strat == "code_block":
                result = _extract_code_block(text)
                if result is not None:
                    return result
            elif strat == "json_block":
                result = _extract_json_block(text)
                if result is not None:
                    return result
            elif strat == "brace":
                result = _extract_brace(text)
                if result is not None:
                    return result
            elif strat == "line":
                result = _extract_first_json_line(text)
                if result is not None:
                    return result
        except Exception as e:
            errors.append(f"{strat}: {str(e)}")
            continue

    # Last resort: try json.loads on entire text
    try:
        return json.loads(text)
    except (json.JSONDecodeError, TypeError):
        pass

    return {
        "_parse_error": f"All strategies failed: {'; '.join(errors)}" if errors else "Unknown parsing error",
        "_raw": original,
    }


def _extract_code_block(text: str) -> dict | None:
    """Extract JSON from markdown code blocks (```json ... ``` or ``` ... ```)."""
    patterns = [
        r"```(?:json)?\s*\n(.*?)\n```",
        r"```(?:json)?\s*(.*?)\s*```",
    ]
    for pattern in patterns:
        matches = re.findall(pattern, text, re.DOTALL)
        for match in matches:
            try:
                return json.loads(match.strip())
            except (json.JSONDecodeError, TypeError):
                continue
    return None


def _extract_json_block(text: str) -> dict | None:
    """Extract JSON starting with { or [ and matching closing bracket."""
    # Find first { or [
    for start_char, end_char in [("{", "}"), ("[", "]")]:
        idx = text.find(start_char)
        if idx == -1:
            continue

        depth = 0
        in_string = False
        escape_next = False
        for i in range(idx, len(text)):
            c = text[i]

            if escape_next:
                escape_next = False
                continue

            if c == "\\":
                escape_next = True
                continue

            if c == '"':
                in_string = not in_string
                continue

            if in_string:
                continue

            if c == start_char:
                depth += 1
            elif c == end_char:
                depth -= 1
                if depth == 0:
                    candidate = text[idx : i + 1]
                    try:
                        return json.loads(candidate)
                    except (json.JSONDecodeError, TypeError):
                        break
    return None


def _extract_brace(text: str) -> dict | None:
    """Extract JSON between outermost { and } with balanced braces."""
    return _extract_json_block(text)


def _extract_first_json_line(text: str) -> dict | None:
    """Try each line as standalone JSON."""
    for line in text.split("\n"):
        line = line.strip()
        if line.startswith("{") or line.startswith("["):
            try:
                return json.loads(line)
            except (json.JSONDecodeError, TypeError):
                continue
    return None


def extract_verilog_code(text: str, module_name: str = "") -> str:
    """
    Extract Verilog code from LLM response.

    Args:
        text: Raw LLM response text
        module_name: Expected module name for validation

    Returns:
        Extracted Verilog code string
    """
    verilog_patterns = [
        r"```(?:verilog|systemverilog|sv)\s*\n(.*?)\n```",
        r"```\s*\n(module\s+.*?endmodule)\s*\n```",
        r"(module\s+\w+.*?endmodule)",
    ]

    for pattern in verilog_patterns:
        matches = re.findall(pattern, text, re.DOTALL | re.IGNORECASE)
        for match in matches:
            code = match.strip()
            if module_name:
                if f"module {module_name}" in code:
                    return code
            elif "module " in code and "endmodule" in code:
                return code

    # Last resort: find everything between first 'module' and last 'endmodule'
    m_start = text.find("module ")
    m_end = text.rfind("endmodule")
    if m_start != -1 and m_end != -1:
        code = text[m_start : m_end + len("endmodule")]
        return code.strip()

    return ""


def extract_testbench_code(text: str, module_name: str = "") -> str:
    """Extract testbench Verilog code from LLM response."""
    tb_patterns = [
        r"```(?:verilog|systemverilog|sv)\s*\n(.*?)\n```",
        r"```\s*\n(.*?)\n```",
        r"(module\s+\w+_tb.*?endmodule)",
    ]

    for pattern in tb_patterns:
        matches = re.findall(pattern, text, re.DOTALL | re.IGNORECASE)
        for match in matches:
            code = match.strip()
            if ("_tb" in code or "testbench" in code.lower()) and "endmodule" in code:
                return code

    return extract_verilog_code(text, module_name)


def sanitize_json_for_llm(obj) -> str:
    """Convert a Python object to a compact JSON string suitable for LLM context."""
    return json.dumps(obj, ensure_ascii=False, separators=(",", ":"))
