#!/bin/bash

# Analyze and generate detailed throughput report
# Creates markdown tables and comparisons from throughput results

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="$SCRIPT_DIR/../results"

THROUGHPUT_FILE="$RESULTS_DIR/throughput_results.json"
LOAD_TEST_FILE="$RESULTS_DIR/load_test_results.json"
REPORT_FILE="$RESULTS_DIR/throughput_analysis.md"

echo "==================================="
echo "Analyzing Throughput Results"
echo "==================================="

# Check if files exist
if [ ! -f "$THROUGHPUT_FILE" ]; then
    echo "ERROR: Throughput results not found. Run benchmark_throughput.sh first."
    exit 1
fi

if [ ! -f "$LOAD_TEST_FILE" ]; then
    echo "WARNING: Load test results not found. Skipping load test analysis."
    LOAD_TEST_AVAILABLE=false
else
    LOAD_TEST_AVAILABLE=true
fi

echo "Generating detailed analysis report..."

# Start markdown report
cat > "$REPORT_FILE" <<'EOF'
# Throughput & Performance Analysis Report

This report provides a detailed analysis of request throughput (req/sec) and performance characteristics under various load conditions.

---

## Test Configuration

EOF

# Add test configuration
jq -r '"- **Concurrency Levels Tested**: \(.test_configuration.concurrency_levels | join(", "))
- **Requests per Test**: \(.test_configuration.requests_per_test)
- **Warmup Requests**: \(.test_configuration.warmup_requests)
- **Endpoints Tested**: \(.test_configuration.endpoints_tested | join(", "))
"' "$THROUGHPUT_FILE" >> "$REPORT_FILE"

# Peak throughput comparison
cat >> "$REPORT_FILE" <<'EOF'

---

## Peak Throughput Comparison

EOF

DOTNET_PEAK=$(jq -r '.dotnet.peak_throughput_rps' "$THROUGHPUT_FILE")
SCALA_PEAK=$(jq -r '.scala_play.peak_throughput_rps' "$THROUGHPUT_FILE")
DIFF_PERCENT=$(jq -r '.comparison.dotnet_faster_by_percent' "$THROUGHPUT_FILE")

cat >> "$REPORT_FILE" <<EOF
| Platform | Peak Throughput (req/sec) | Relative Performance |
|----------|---------------------------|---------------------|
| .NET     | **${DOTNET_PEAK}** | $(if (( $(echo "$DOTNET_PEAK > $SCALA_PEAK" | bc -l) )); then echo "🏆 Baseline"; else echo "${DIFF_PERCENT}% slower"; fi) |
| Scala Play | **${SCALA_PEAK}** | $(if (( $(echo "$SCALA_PEAK > $DOTNET_PEAK" | bc -l) )); then echo "🏆 Baseline"; else SCALA_DIFF=$(echo "scale=2; (($SCALA_PEAK - $DOTNET_PEAK) / $DOTNET_PEAK) * 100" | bc); echo "${SCALA_DIFF}% slower"; fi) |

EOF

# Throughput by endpoint and concurrency
cat >> "$REPORT_FILE" <<'EOF'

---

## Throughput by Endpoint

### .NET Results

EOF

# Get all endpoints
ENDPOINTS=$(jq -r '.dotnet.endpoints | keys[]' "$THROUGHPUT_FILE")

for endpoint in $ENDPOINTS; do
    cat >> "$REPORT_FILE" <<EOF

#### Endpoint: \`$endpoint\`

| Concurrency | Req/Sec | Mean Latency (ms) | P95 Latency (ms) | P99 Latency (ms) | Failed Requests |
|-------------|---------|-------------------|------------------|------------------|-----------------|
EOF

    # Get concurrency levels for this endpoint
    CONCURRENCIES=$(jq -r ".dotnet.endpoints.$endpoint | keys[]" "$THROUGHPUT_FILE" | sed 's/c//')

    for concurrency in $CONCURRENCIES; do
        jq -r ".dotnet.endpoints.$endpoint.c$concurrency |
        \"| $concurrency | \(.requests_per_second) | \(.mean_latency_ms) | \(.percentiles.p95_ms) | \(.percentiles.p99_ms) | \(.failed_requests) |\"" \
        "$THROUGHPUT_FILE" >> "$REPORT_FILE"
    done
done

cat >> "$REPORT_FILE" <<'EOF'

### Scala Play Results

EOF

for endpoint in $ENDPOINTS; do
    cat >> "$REPORT_FILE" <<EOF

#### Endpoint: \`$endpoint\`

| Concurrency | Req/Sec | Mean Latency (ms) | P95 Latency (ms) | P99 Latency (ms) | Failed Requests |
|-------------|---------|-------------------|------------------|------------------|-----------------|
EOF

    # Get concurrency levels for this endpoint
    CONCURRENCIES=$(jq -r ".scala_play.endpoints.$endpoint | keys[]" "$THROUGHPUT_FILE" | sed 's/c//')

    for concurrency in $CONCURRENCIES; do
        jq -r ".scala_play.endpoints.$endpoint.c$concurrency |
        \"| $concurrency | \(.requests_per_second) | \(.mean_latency_ms) | \(.percentiles.p95_ms) | \(.percentiles.p99_ms) | \(.failed_requests) |\"" \
        "$THROUGHPUT_FILE" >> "$REPORT_FILE"
    done
done

# Add load test results if available
if [ "$LOAD_TEST_AVAILABLE" = true ]; then
    cat >> "$REPORT_FILE" <<'EOF'

---

## Progressive Load Test Results

This test gradually increases the load to find the breaking point and maximum sustainable throughput.

EOF

    DOTNET_LOAD_PEAK=$(jq -r '.dotnet.peak_sustainable_rps' "$LOAD_TEST_FILE")
    DOTNET_LOAD_CONCURRENCY=$(jq -r '.dotnet.peak_sustainable_concurrency' "$LOAD_TEST_FILE")
    SCALA_LOAD_PEAK=$(jq -r '.scala_play.peak_sustainable_rps' "$LOAD_TEST_FILE")
    SCALA_LOAD_CONCURRENCY=$(jq -r '.scala_play.peak_sustainable_concurrency' "$LOAD_TEST_FILE")

    cat >> "$REPORT_FILE" <<EOF

### Peak Sustainable Performance

| Platform | Max Sustainable RPS | Optimal Concurrency | Error Rate |
|----------|---------------------|---------------------|------------|
| .NET     | **${DOTNET_LOAD_PEAK}** | ${DOTNET_LOAD_CONCURRENCY} | < 1% |
| Scala Play | **${SCALA_LOAD_PEAK}** | ${SCALA_LOAD_CONCURRENCY} | < 1% |

### .NET Load Test Progression

| Concurrency | Req/Sec | Completed | Failed | Error % |
|-------------|---------|-----------|--------|---------|
EOF

    jq -r '.dotnet.load_test_results[] |
    "| \(.concurrency) | \(.requests_per_second) | \(.completed_requests) | \(.failed_requests) | \(.error_rate_percent) |"' \
    "$LOAD_TEST_FILE" >> "$REPORT_FILE"

    cat >> "$REPORT_FILE" <<'EOF'

### Scala Play Load Test Progression

| Concurrency | Req/Sec | Completed | Failed | Error % |
|-------------|---------|-----------|--------|---------|
EOF

    jq -r '.scala_play.load_test_results[] |
    "| \(.concurrency) | \(.requests_per_second) | \(.completed_requests) | \(.failed_requests) | \(.error_rate_percent) |"' \
    "$LOAD_TEST_FILE" >> "$REPORT_FILE"
fi

# Add key findings
cat >> "$REPORT_FILE" <<'EOF'

---

## Key Findings

### Throughput Characteristics

EOF

# Analyze which platform is better at different concurrency levels
echo "Analyzing performance patterns..."

# Simple endpoint at low concurrency
DOTNET_LOW=$(jq -r '.dotnet.endpoints.hello.c10.requests_per_second' "$THROUGHPUT_FILE")
SCALA_LOW=$(jq -r '.scala_play.endpoints.hello.c10.requests_per_second' "$THROUGHPUT_FILE")

# Simple endpoint at high concurrency
DOTNET_HIGH=$(jq -r '.dotnet.endpoints.hello.c200.requests_per_second' "$THROUGHPUT_FILE")
SCALA_HIGH=$(jq -r '.scala_play.endpoints.hello.c200.requests_per_second' "$THROUGHPUT_FILE")

cat >> "$REPORT_FILE" <<EOF

**Low Concurrency Performance (10 concurrent connections):**
- .NET: ${DOTNET_LOW} req/sec
- Scala Play: ${SCALA_LOW} req/sec
- Winner: $(if (( $(echo "$DOTNET_LOW > $SCALA_LOW" | bc -l) )); then echo ".NET"; else echo "Scala Play"; fi)

**High Concurrency Performance (200 concurrent connections):**
- .NET: ${DOTNET_HIGH} req/sec
- Scala Play: ${SCALA_HIGH} req/sec
- Winner: $(if (( $(echo "$DOTNET_HIGH > $SCALA_HIGH" | bc -l) )); then echo ".NET"; else echo "Scala Play"; fi)

### Latency Analysis

EOF

# P99 latency comparison
DOTNET_P99=$(jq -r '.dotnet.endpoints.hello.c100.percentiles.p99_ms' "$THROUGHPUT_FILE")
SCALA_P99=$(jq -r '.scala_play.endpoints.hello.c100.percentiles.p99_ms' "$THROUGHPUT_FILE")

cat >> "$REPORT_FILE" <<EOF
**99th Percentile Latency (100 concurrent connections):**
- .NET: ${DOTNET_P99}ms
- Scala Play: ${SCALA_P99}ms
- Better latency: $(if (( $(echo "$DOTNET_P99 < $SCALA_P99" | bc -l) )); then echo ".NET (lower is better)"; else echo "Scala Play (lower is better)"; fi)

### Endpoint Performance Comparison

The benchmark tested multiple endpoint types to understand performance under different workloads:

- **hello**: Simple GET request, minimal processing
- **echo**: GET with parameter, string manipulation
- **compute_light**: Light CPU work (1,000 iterations)
- **compute_heavy**: Heavy CPU work (10,000 iterations)

EOF

# Find best and worst performing endpoints for each platform
DOTNET_BEST=$(echo "$ENDPOINTS" | while read ep; do
    rps=$(jq -r ".dotnet.endpoints.$ep.c100.requests_per_second" "$THROUGHPUT_FILE")
    echo "$rps $ep"
done | sort -rn | head -1)

SCALA_BEST=$(echo "$ENDPOINTS" | while read ep; do
    rps=$(jq -r ".scala_play.endpoints.$ep.c100.requests_per_second" "$THROUGHPUT_FILE")
    echo "$rps $ep"
done | sort -rn | head -1)

cat >> "$REPORT_FILE" <<EOF
**.NET Best Performing Endpoint:** $(echo $DOTNET_BEST | awk '{print $2}') at $(echo $DOTNET_BEST | awk '{print $1}') req/sec

**Scala Play Best Performing Endpoint:** $(echo $SCALA_BEST | awk '{print $2}') at $(echo $SCALA_BEST | awk '{print $1}') req/sec

---

## Recommendations

Based on the benchmark results:

EOF

# Provide recommendations based on results
if (( $(echo "$DOTNET_PEAK > $SCALA_PEAK" | bc -l) )); then
    cat >> "$REPORT_FILE" <<EOF
1. **.NET shows higher peak throughput** (${DIFF_PERCENT}% faster)
   - Better choice for high-traffic scenarios
   - More efficient under heavy concurrent load

2. **Scala Play considerations:**
   - May offer better functional programming paradigms
   - JVM warm-up time may affect initial performance
   - Consider tuning JVM parameters for better performance

EOF
else
    SCALA_ADVANTAGE=$(echo "scale=2; (($SCALA_PEAK - $DOTNET_PEAK) / $DOTNET_PEAK) * 100" | bc)
    cat >> "$REPORT_FILE" <<EOF
1. **Scala Play shows higher peak throughput** (${SCALA_ADVANTAGE}% faster)
   - Better choice for high-traffic scenarios
   - JVM optimizations working effectively

2. **.NET considerations:**
   - May have faster cold start times
   - Consider async/await patterns for better concurrency
   - Tune thread pool settings for better performance

EOF
fi

cat >> "$REPORT_FILE" <<'EOF'

3. **General Recommendations:**
   - Always load test with your specific workload patterns
   - Monitor latency percentiles (P95, P99) in production
   - Consider horizontal scaling for both platforms
   - Implement proper caching strategies
   - Use connection pooling and async I/O

---

*Report generated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF

echo "Analysis complete!"
echo "Report saved to: $REPORT_FILE"
