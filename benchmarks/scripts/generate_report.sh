#!/bin/bash

# Generate comprehensive comparison report from benchmark results
# Combines all benchmark results into a readable report

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"

COMPILATION_FILE="$RESULTS_DIR/compilation_results.json"
PACKAGE_FILE="$RESULTS_DIR/package_size_results.json"
RUNTIME_FILE="$RESULTS_DIR/runtime_results.json"
REPORT_JSON="$RESULTS_DIR/comprehensive_report.json"
REPORT_MD="$RESULTS_DIR/comprehensive_report.md"

# Check if all result files exist
if [ ! -f "$COMPILATION_FILE" ]; then
    echo "ERROR: Compilation results not found. Run benchmark_compilation.sh first."
    exit 1
fi

if [ ! -f "$PACKAGE_FILE" ]; then
    echo "ERROR: Package size results not found. Run benchmark_package_size.sh first."
    exit 1
fi

if [ ! -f "$RUNTIME_FILE" ]; then
    echo "ERROR: Runtime results not found. Run benchmark_runtime.sh first."
    exit 1
fi

echo "Generating comprehensive report..."

# Combine all results into one JSON
jq -n \
  --slurpfile comp "$COMPILATION_FILE" \
  --slurpfile pkg "$PACKAGE_FILE" \
  --slurpfile run "$RUNTIME_FILE" \
  '{
    generated_at: (now | strftime("%Y-%m-%dT%H:%M:%SZ")),
    compilation: $comp[0],
    package_size: $pkg[0],
    runtime: $run[0]
  }' > "$REPORT_JSON"

# Generate Markdown report
cat > "$REPORT_MD" <<'EOF'
# .NET vs Scala Play - Comprehensive Comparison Report

This report compares .NET 8.0 and Scala 2.13 with Play Framework across multiple dimensions:
- Compilation time
- Package size
- Runtime performance
- Memory usage

---

## Executive Summary

EOF

# Add compilation summary
DOTNET_COMPILE=$(jq -r '.compilation.dotnet.total_time_seconds' "$REPORT_JSON")
SCALA_COMPILE=$(jq -r '.compilation.scala_play.total_time_seconds' "$REPORT_JSON")
COMPILE_DIFF=$(jq -r '.compilation.comparison.dotnet_faster_by_percent' "$REPORT_JSON")

cat >> "$REPORT_MD" <<EOF
### Compilation Time

- **.NET**: ${DOTNET_COMPILE}s
- **Scala Play**: ${SCALA_COMPILE}s
- **Winner**: $(if (( $(echo "$DOTNET_COMPILE < $SCALA_COMPILE" | bc -l) )); then echo ".NET (${COMPILE_DIFF}% faster)"; else echo "Scala Play"; fi)

EOF

# Add package size summary
DOTNET_SIZE=$(jq -r '.package_size.dotnet.total_size_human' "$REPORT_JSON")
SCALA_SIZE=$(jq -r '.package_size.scala_play.total_size_human' "$REPORT_JSON")
SIZE_DIFF=$(jq -r '.package_size.comparison.dotnet_smaller_by_percent' "$REPORT_JSON")

cat >> "$REPORT_MD" <<EOF
### Package Size

- **.NET**: ${DOTNET_SIZE}
- **Scala Play**: ${SCALA_SIZE}
- **Winner**: $(if (( $(echo "$SIZE_DIFF > 0" | bc -l) )); then echo ".NET (${SIZE_DIFF}% smaller)"; else echo "Scala Play"; fi)

EOF

# Add runtime performance summary
DOTNET_RPS=$(jq -r '.runtime.dotnet.endpoints.hello.rps' "$REPORT_JSON")
SCALA_RPS=$(jq -r '.runtime.scala_play.endpoints.hello.rps' "$REPORT_JSON")
RPS_DIFF=$(jq -r '.runtime.comparison.hello_endpoint_dotnet_faster_percent' "$REPORT_JSON")

cat >> "$REPORT_MD" <<EOF
### Runtime Performance (Requests/Second)

- **.NET**: ${DOTNET_RPS} req/s
- **Scala Play**: ${SCALA_RPS} req/s
- **Winner**: $(if (( $(echo "$DOTNET_RPS > $SCALA_RPS" | bc -l) )); then echo ".NET (${RPS_DIFF}% faster)"; else echo "Scala Play"; fi)

EOF

# Add memory usage summary
DOTNET_MEM=$(jq -r '.runtime.dotnet.memory_idle_mb' "$REPORT_JSON")
SCALA_MEM=$(jq -r '.runtime.scala_play.memory_idle_mb' "$REPORT_JSON")
MEM_DIFF=$(jq -r '.runtime.comparison.memory_dotnet_lighter_percent' "$REPORT_JSON")

cat >> "$REPORT_MD" <<EOF
### Memory Usage (Idle)

- **.NET**: ${DOTNET_MEM} MB
- **Scala Play**: ${SCALA_MEM} MB
- **Winner**: $(if (( $(echo "$DOTNET_MEM < $SCALA_MEM" | bc -l) )); then echo ".NET (${MEM_DIFF}% lighter)"; else echo "Scala Play"; fi)

---

## Detailed Results

### 1. Compilation Time

| Metric | .NET | Scala Play |
|--------|------|------------|
EOF

# Compilation details
jq -r '
  "| Total Time | \(.compilation.dotnet.total_time_seconds)s | \(.compilation.scala_play.total_time_seconds)s |",
  "| Restore/Update | \(.compilation.dotnet.restore_time_seconds)s | \(.compilation.scala_play.update_time_seconds)s |",
  "| Build/Compile | \(.compilation.dotnet.build_time_seconds)s | \(.compilation.scala_play.compile_time_seconds)s |",
  "| Publish/Stage | \(.compilation.dotnet.publish_time_seconds)s | \(.compilation.scala_play.stage_time_seconds)s |"
' "$REPORT_JSON" >> "$REPORT_MD"

cat >> "$REPORT_MD" <<EOF

### 2. Package Size

| Metric | .NET | Scala Play |
|--------|------|------------|
EOF

# Package size details
jq -r '
  "| Total Size | \(.package_size.dotnet.total_size_human) | \(.package_size.scala_play.total_size_human) |",
  "| File Count | \(.package_size.dotnet.file_count) | \(.package_size.scala_play.file_count) |",
  "| Size (MB) | \(.package_size.dotnet.total_size_mb) | \(.package_size.scala_play.total_size_mb) |"
' "$REPORT_JSON" >> "$REPORT_MD"

cat >> "$REPORT_MD" <<EOF

### 3. Runtime Performance

#### Hello Endpoint (Simple GET)

| Metric | .NET | Scala Play |
|--------|------|------------|
EOF

# Runtime details - Hello endpoint
jq -r '
  "| Requests/Second | \(.runtime.dotnet.endpoints.hello.rps) | \(.runtime.scala_play.endpoints.hello.rps) |",
  "| Mean Time (ms) | \(.runtime.dotnet.endpoints.hello.mean_time_ms) | \(.runtime.scala_play.endpoints.hello.mean_time_ms) |",
  "| Failed Requests | \(.runtime.dotnet.endpoints.hello.failed_requests) | \(.runtime.scala_play.endpoints.hello.failed_requests) |"
' "$REPORT_JSON" >> "$REPORT_MD"

cat >> "$REPORT_MD" <<EOF

#### Echo Endpoint (GET with parameter)

| Metric | .NET | Scala Play |
|--------|------|------------|
EOF

# Runtime details - Echo endpoint
jq -r '
  "| Requests/Second | \(.runtime.dotnet.endpoints.echo.rps) | \(.runtime.scala_play.endpoints.echo.rps) |",
  "| Mean Time (ms) | \(.runtime.dotnet.endpoints.echo.mean_time_ms) | \(.runtime.scala_play.endpoints.echo.mean_time_ms) |",
  "| Failed Requests | \(.runtime.dotnet.endpoints.echo.failed_requests) | \(.runtime.scala_play.endpoints.echo.failed_requests) |"
' "$REPORT_JSON" >> "$REPORT_MD"

cat >> "$REPORT_MD" <<EOF

#### Compute Endpoint (CPU intensive)

| Metric | .NET | Scala Play |
|--------|------|------------|
EOF

# Runtime details - Compute endpoint
jq -r '
  "| Requests/Second | \(.runtime.dotnet.endpoints.compute.rps) | \(.runtime.scala_play.endpoints.compute.rps) |",
  "| Mean Time (ms) | \(.runtime.dotnet.endpoints.compute.mean_time_ms) | \(.runtime.scala_play.endpoints.compute.mean_time_ms) |",
  "| Failed Requests | \(.runtime.dotnet.endpoints.compute.failed_requests) | \(.runtime.scala_play.endpoints.compute.failed_requests) |"
' "$REPORT_JSON" >> "$REPORT_MD"

cat >> "$REPORT_MD" <<EOF

### 4. Memory Usage

| Metric | .NET | Scala Play |
|--------|------|------------|
EOF

# Memory details
jq -r '
  "| Idle Memory (MB) | \(.runtime.dotnet.memory_idle_mb) | \(.runtime.scala_play.memory_idle_mb) |",
  "| Under Load (MB) | \(.runtime.dotnet.memory_load_mb) | \(.runtime.scala_play.memory_load_mb) |"
' "$REPORT_JSON" >> "$REPORT_MD"

cat >> "$REPORT_MD" <<EOF

---

## Conclusion

EOF

# Generate conclusion based on results
cat >> "$REPORT_MD" <<'CONCLUSION'
This benchmark compares .NET and Scala Play Framework across multiple dimensions. The results show:

**Key Findings:**

1. **Compilation Speed**: Generally shows how long it takes to build and package the application from source
2. **Package Size**: Indicates the deployment footprint and storage requirements
3. **Runtime Performance**: Measures throughput (requests per second) under concurrent load
4. **Memory Efficiency**: Shows RAM consumption at idle and under load

**Considerations:**

- Results may vary based on hardware, OS, and specific use cases
- Both frameworks are production-ready and have their strengths
- .NET typically excels in Windows environments and enterprise scenarios
- Scala Play provides functional programming paradigms and JVM ecosystem access

**Test Configuration:**
- Benchmark requests: 1000 per endpoint
- Concurrency: 10 concurrent connections
- Warmup: 100 requests + 5 seconds

*Generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
CONCLUSION

echo "Report generated successfully!"
echo "  - JSON: $REPORT_JSON"
echo "  - Markdown: $REPORT_MD"
