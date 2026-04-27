#!/usr/bin/env python3
import os
import sys
import argparse
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from src.verigraphi import VeriGraphiPipeline


def full_pipeline(args):
    api_key = args.key or os.environ.get("MINIMAX_API_KEY")
    if not api_key:
        print("Error: API key required. Set MINIMAX_API_KEY or use --key")
        sys.exit(1)

    spec_path = Path(args.spec)
    if not spec_path.exists():
        print(f"Error: Spec file not found: {args.spec}")
        sys.exit(1)

    print(f"Running full pipeline on {spec_path}")

    pipeline = VeriGraphiPipeline(
        api_key=api_key,
        model=args.model or "MiniMax-Text-01",
        provider=args.provider or "minimax"
    )

    result = pipeline.run(
        spec_path=str(spec_path),
        output_dir=args.output or "./output"
    )

    if result.get("success"):
        print(f"\nSuccess! Output in: {result.get('output_dir')}")
        print(f"Modules: {', '.join(result.get('modules_generated', []))}")
    else:
        print(f"\nFailed: {result.get('error')}")
        sys.exit(1)


def analyze_command(args):
    from src.agents.base import LLMClient
    from src.agents.architectural_analysis import ArchitecturalAnalysisPipeline

    api_key = args.key or os.environ.get("MINIMAX_API_KEY")
    if not api_key:
        print("Error: API key required")
        sys.exit(1)

    spec_path = Path(args.spec)
    if not spec_path.exists():
        print(f"Error: Spec file not found: {args.spec}")
        sys.exit(1)

    with open(spec_path, 'r') as f:
        spec_content = f.read()

    print(f"Analyzing {spec_path}...")

    llm_client = LLMClient(
        provider=args.provider or "minimax",
        api_key=api_key,
        model=args.model or "MiniMax-Text-01"
    )

    pipeline = ArchitecturalAnalysisPipeline(llm_client)
    result = pipeline.run(spec_content)

    if result.get("success"):
        print("\n" + "=" * 60)
        print("Analysis Results")
        print("=" * 60)
        print(f"\nModules identified: {len(result.get('modules', []))}")
        for i, m in enumerate(result.get('modules', [])[:10]):
            print(f"  {i+1}. {m.get('name', 'unknown')}")
        if len(result.get('modules', [])) > 10:
            print(f"  ... and {len(result.get('modules', [])) - 10} more")

        audit = result.get('audit', {})
        if audit:
            print(f"\nAudit: {'PASSED' if audit.get('audit_passed') else 'FAILED'}")
            issues = audit.get('issues', [])
            if issues:
                print(f"Issues found: {len(issues)}")
                for issue in issues[:5]:
                    print(f"  - [{issue.get('severity', '?')}] {issue.get('description', '')}")

        output_path = Path(args.output) if args.output else Path("./output")
        output_path.mkdir(parents=True, exist_ok=True)
        import json
        with open(output_path / "analysis_result.json", 'w') as f:
            json.dump(result, f, indent=2)
        print(f"\nFull results saved to: {output_path / 'analysis_result.json'}")
    else:
        print(f"\nAnalysis failed: {result.get('error')}")
        sys.exit(1)


def generate_command(args):
    print("Generation requires completed analysis.")
    print("Run 'python cli.py full --spec spec/RISCV_Core_Spec.md --key YOUR_KEY' instead.")


def main():
    parser = argparse.ArgumentParser(
        description="VeriGraphi - Multi-Agent RTL Generation Framework"
    )
    subparsers = parser.add_subparsers(dest="command", help="Commands")

    full_parser = subparsers.add_parser("full", help="Run full pipeline")
    full_parser.add_argument("--spec", required=True, help="Path to specification file")
    full_parser.add_argument("--key", help="API key (or set MINIMAX_API_KEY)")
    full_parser.add_argument("--model", default="MiniMax-Text-01", help="Model name")
    full_parser.add_argument("--provider", default="minimax", help="LLM provider")
    full_parser.add_argument("--output", default="./output", help="Output directory")

    analyze_parser = subparsers.add_parser("analyze", help="Run architectural analysis only")
    analyze_parser.add_argument("--spec", required=True, help="Path to specification file")
    analyze_parser.add_argument("--key", help="API key (or set MINIMAX_API_KEY)")
    analyze_parser.add_argument("--model", default="MiniMax-Text-01", help="Model name")
    analyze_parser.add_argument("--provider", default="minimax", help="LLM provider")
    analyze_parser.add_argument("--output", default="./output", help="Output directory")

    gen_parser = subparsers.add_parser("generate", help="Generate RTL from analysis")
    gen_parser.add_argument("--key", help="API key (or set MINIMAX_API_KEY)")
    gen_parser.add_argument("--output", default="./output", help="Output directory")

    args = parser.parse_args()

    if not args.command:
        parser.print_help()
        sys.exit(1)

    if args.command == "full":
        full_pipeline(args)
    elif args.command == "analyze":
        analyze_command(args)
    elif args.command == "generate":
        generate_command(args)


if __name__ == "__main__":
    main()
