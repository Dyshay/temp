#!/bin/bash

# Master script to run all throughput/req-sec benchmarks
# This provides a complete performance analysis under various load conditions

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"

echo "==========================================="
echo "  Throughput & Load Testing Suite"
echo "==========================================="
echo ""
echo "This suite will run:"
echo "  1. Multi-concurrency throughput test"
echo "  2. Progressive load test (find breaking point)"
echo "  3. Generate detailed analysis report"
echo ""
echo "Estimated time: 20-30 minutes"
echo ""
read -p "Press Enter to continue or Ctrl+C to cancel..."

# Create results directory
mkdir -p "$RESULTS_DIR"

# Run throughput benchmark
echo ""
echo "==========================================="
echo "Step 1/3: Multi-Concurrency Throughput Test"
echo "==========================================="
echo "Testing with concurrency levels: 1, 10, 50, 100, 200"
echo ""
bash "$SCRIPT_DIR/benchmark_throughput.sh"

# Run progressive load test
echo ""
echo "==========================================="
echo "Step 2/3: Progressive Load Test"
echo "==========================================="
echo "Gradually increasing load to find breaking point"
echo ""
bash "$SCRIPT_DIR/benchmark_load_test.sh"

# Generate analysis
echo ""
echo "==========================================="
echo "Step 3/3: Generating Analysis Report"
echo "==========================================="
bash "$SCRIPT_DIR/analyze_throughput.sh"

echo ""
echo "==========================================="
echo "Throughput Testing Complete!"
echo "==========================================="
echo ""
echo "Results available in: $RESULTS_DIR/"
echo "  - throughput_results.json"
echo "  - load_test_results.json"
echo "  - throughput_analysis.md (detailed report)"
echo ""
echo "View the analysis report:"
echo "  cat $RESULTS_DIR/throughput_analysis.md"
echo ""
