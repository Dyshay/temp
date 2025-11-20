#!/bin/bash

# Master script to run all benchmarks
# This script runs compilation, package size, and runtime benchmarks

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"

echo "==========================================="
echo "  .NET vs Scala Play - Full Benchmark Suite"
echo "==========================================="
echo ""
echo "This will run the following benchmarks:"
echo "  1. Compilation time"
echo "  2. Package size"
echo "  3. Startup time (cold, warm, hot)"
echo "  4. Runtime performance & RAM usage"
echo "  5. JSON serialization/deserialization"
echo "  6. LINQ vs Collections"
echo ""
echo "Estimated time: 30-45 minutes"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Create results directory
mkdir -p "$RESULTS_DIR"

# Clear old results
echo ""
echo "Clearing old results..."
rm -f "$RESULTS_DIR"/*.json

# Run compilation benchmark
echo ""
echo "==========================================="
echo "Step 1/6: Compilation Benchmark"
echo "==========================================="
bash "$SCRIPT_DIR/benchmark_compilation.sh"

# Run package size benchmark
echo ""
echo "==========================================="
echo "Step 2/6: Package Size Benchmark"
echo "==========================================="
bash "$SCRIPT_DIR/benchmark_package_size.sh"

# Run startup time benchmark
echo ""
echo "==========================================="
echo "Step 3/6: Startup Time Benchmark"
echo "==========================================="
bash "$SCRIPT_DIR/benchmark_startup.sh"

# Run runtime benchmark
echo ""
echo "==========================================="
echo "Step 4/6: Runtime Performance Benchmark"
echo "==========================================="
bash "$SCRIPT_DIR/benchmark_runtime.sh"

# Run JSON serialization benchmark
echo ""
echo "==========================================="
echo "Step 5/6: JSON Serialization Benchmark"
echo "==========================================="
bash "$SCRIPT_DIR/benchmark_json.sh"

# Run LINQ & Collections benchmark
echo ""
echo "==========================================="
echo "Step 6/6: LINQ & Collections Benchmark"
echo "==========================================="
bash "$SCRIPT_DIR/benchmark_linq_collections.sh"

# Generate comprehensive report
echo ""
echo "==========================================="
echo "Generating Comprehensive Report"
echo "==========================================="
bash "$SCRIPT_DIR/generate_report.sh"

echo ""
echo "==========================================="
echo "All Benchmarks Complete!"
echo "==========================================="
echo ""
echo "Results available in: $RESULTS_DIR/"
echo "  - compilation_results.json"
echo "  - package_size_results.json"
echo "  - startup_results.json"
echo "  - runtime_results.json"
echo "  - json_results.json"
echo "  - linq_collections_results.json"
echo "  - comprehensive_report.md"
echo "  - comprehensive_report.json"
echo ""
