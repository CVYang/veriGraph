#!/usr/bin/env python3
import os
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))

from src.verigraphi import VeriGraphiPipeline


def main():
    api_key = os.environ.get("MINIMAX_API_KEY")
    if not api_key:
        print("Error: MINIMAX_API_KEY environment variable not set")
        print("Please set it with: export MINIMAX_API_KEY='your-api-key'")
        sys.exit(1)

    spec_path = Path(__file__).parent / "spec" / "RISCV_Core_Spec.md"
    if not spec_path.exists():
        print(f"Error: Spec file not found at {spec_path}")
        sys.exit(1)

    print("=" * 60)
    print("VeriGraphi - Multi-Agent RTL Generation Pipeline")
    print("=" * 60)
    print(f"Spec: {spec_path}")
    print(f"Output: ./output")
    print(f"Log files: ./output/logs/")
    print(f"Checkpoints: ./output/.checkpoints/")
    print("=" * 60)

    pipeline = VeriGraphiPipeline(
        api_key=api_key,
        model="MiniMax-M2.7",
        provider="minimax"
    )

    result = pipeline.run(
        spec_path=str(spec_path),
        output_dir="./output",
        resume=False
    )

    if result.get("success"):
        print("\n" + "=" * 60)
        print("Pipeline completed successfully!")
        print("=" * 60)
        print(f"Output directory: {result.get('output_dir')}")
        print(f"Modules generated: {', '.join(result.get('modules_generated', []))}")
        print(f"Verification status: {result.get('verification_status')}")
        print("\nGenerated files:")
        print("  - RTL modules: ./output/rtl/")
        print("  - Knowledge Graph: ./output/kg/hda.json")
        print("  - Implementation Plan: ./output/implementation_plan.json")
        print("  - Testbenches: ./output/tests/")
        print("  - Logs: ./output/logs/")
        print("  - Checkpoints: ./output/.checkpoints/")
    else:
        print("\n" + "=" * 60)
        print("Pipeline failed!")
        print("=" * 60)
        print(f"Error: {result.get('error', 'Unknown error')}")
        print("\nCheck logs for details: ./output/logs/")


if __name__ == "__main__":
    main()
