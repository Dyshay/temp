#!/bin/bash

# Advanced throughput benchmark (req/sec) for .NET and Scala Play
# Tests with multiple concurrency levels and endpoints
# Output: Detailed JSON file with throughput metrics

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/benchmarks/results"

mkdir -p "$RESULTS_DIR"

echo "==================================="
echo "Advanced Throughput Benchmark"
echo "==================================="

# Configuration - Test with increasing concurrency levels
CONCURRENCY_LEVELS=(1 10 50 100 200)
REQUESTS_PER_TEST=10000
WARMUP_REQUESTS=500
WARMUP_TIME=5

# Endpoints to test
declare -A ENDPOINTS
ENDPOINTS=(
    ["hello"]="/api/hello"
    ["echo"]="/api/echo/benchmark"
    ["compute_light"]="/api/compute/1000"
    ["compute_heavy"]="/api/compute/10000"
)

# Function to wait for service
wait_for_service() {
    local url=$1
    local max_attempts=30
    local attempt=0

    echo "  Waiting for service at $url..."
    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            echo "  Service is ready!"
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 2
    done
    echo "  ERROR: Service did not start in time"
    return 1
}

# Function to run throughput test with Apache Bench
run_ab_test() {
    local url=$1
    local concurrency=$2
    local requests=$3

    # Run ab and capture output
    local ab_output=$(ab -n $requests -c $concurrency -q "$url" 2>&1)

    # Extract metrics
    local rps=$(echo "$ab_output" | grep "Requests per second" | awk '{print $4}')
    local mean_time=$(echo "$ab_output" | grep "Time per request" | head -1 | awk '{print $4}')
    local failed=$(echo "$ab_output" | grep "Failed requests" | awk '{print $3}')
    local transfer_rate=$(echo "$ab_output" | grep "Transfer rate" | awk '{print $3}')

    # Extract percentile latencies
    local p50=$(echo "$ab_output" | grep "50%" | awk '{print $2}')
    local p75=$(echo "$ab_output" | grep "75%" | awk '{print $2}')
    local p90=$(echo "$ab_output" | grep "90%" | awk '{print $2}')
    local p95=$(echo "$ab_output" | grep "95%" | awk '{print $2}')
    local p99=$(echo "$ab_output" | grep "99%" | awk '{print $2}')

    # Return JSON
    cat <<EOF
{
  "requests_per_second": ${rps:-0},
  "mean_latency_ms": ${mean_time:-0},
  "failed_requests": ${failed:-0},
  "transfer_rate_kb_per_sec": ${transfer_rate:-0},
  "percentiles": {
    "p50_ms": ${p50:-0},
    "p75_ms": ${p75:-0},
    "p90_ms": ${p90:-0},
    "p95_ms": ${p95:-0},
    "p99_ms": ${p99:-0}
  }
}
EOF
}

# Function to benchmark all endpoints at various concurrency levels
benchmark_service() {
    local name=$1
    local base_url=$2
    local pid=$3

    echo ""
    echo "Benchmarking $name..."

    # Warmup
    echo "  Warming up ($WARMUP_REQUESTS requests)..."
    ab -n $WARMUP_REQUESTS -c 10 -q "$base_url/api/hello" > /dev/null 2>&1
    sleep $WARMUP_TIME

    local results="{"
    local first_endpoint=true

    # Test each endpoint
    for endpoint_name in "${!ENDPOINTS[@]}"; do
        local endpoint_path="${ENDPOINTS[$endpoint_name]}"
        local full_url="$base_url$endpoint_path"

        if [ "$first_endpoint" = false ]; then
            results+=","
        fi
        first_endpoint=false

        results+="\"$endpoint_name\":{"
        echo ""
        echo "  Testing endpoint: $endpoint_name ($endpoint_path)"

        local first_concurrency=true
        for concurrency in "${CONCURRENCY_LEVELS[@]}"; do
            echo "    Concurrency: $concurrency"

            if [ "$first_concurrency" = false ]; then
                results+=","
            fi
            first_concurrency=false

            # Run test
            local test_result=$(run_ab_test "$full_url" $concurrency $REQUESTS_PER_TEST)
            local rps=$(echo "$test_result" | jq -r '.requests_per_second')

            echo "      → ${rps} req/sec"

            results+="\"c${concurrency}\":$test_result"

            # Small delay between tests
            sleep 1
        done

        results+="}"
    done

    results+="}"
    echo "$results"
}

# Ensure applications are built
echo ""
echo "Ensuring applications are built..."

cd "$PROJECT_ROOT/dotnet-api"
if [ ! -d "./publish" ]; then
    echo "  Building .NET application..."
    dotnet publish -c Release -o ./publish > /dev/null 2>&1
fi

cd "$PROJECT_ROOT/scala-play-api"
if [ ! -d "./target/universal/stage" ]; then
    echo "  Building Scala Play application..."
    sbt stage > /dev/null 2>&1
fi

# Start .NET application
echo ""
echo "Starting .NET application..."
cd "$PROJECT_ROOT/dotnet-api"
dotnet ./publish/DotNetApi.dll > /dev/null 2>&1 &
DOTNET_PID=$!
echo "  Started with PID: $DOTNET_PID"

wait_for_service "http://127.0.0.1:5000/api/hello"

# Benchmark .NET
DOTNET_RESULTS=$(benchmark_service ".NET" "http://127.0.0.1:5000" $DOTNET_PID)

# Stop .NET
echo ""
echo "Stopping .NET application..."
kill $DOTNET_PID 2>/dev/null || true
wait $DOTNET_PID 2>/dev/null || true
sleep 2

# Start Scala Play application
echo ""
echo "Starting Scala Play application..."
cd "$PROJECT_ROOT/scala-play-api"
./target/universal/stage/bin/scala-play-api > /dev/null 2>&1 &
SCALA_PID=$!
echo "  Started with PID: $SCALA_PID"

wait_for_service "http://127.0.0.1:9000/api/hello"

# Benchmark Scala Play
SCALA_RESULTS=$(benchmark_service "Scala Play" "http://127.0.0.1:9000" $SCALA_PID)

# Stop Scala Play
echo ""
echo "Stopping Scala Play application..."
kill $SCALA_PID 2>/dev/null || true
wait $SCALA_PID 2>/dev/null || true

# Generate JSON report with comparison
echo ""
echo "Generating report..."

# Calculate peak throughput for each
DOTNET_PEAK=$(echo "$DOTNET_RESULTS" | jq '[.[] | .[] | .requests_per_second] | max')
SCALA_PEAK=$(echo "$SCALA_RESULTS" | jq '[.[] | .[] | .requests_per_second] | max')

cat > "$RESULTS_DIR/throughput_results.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_configuration": {
    "concurrency_levels": [$(IFS=,; echo "${CONCURRENCY_LEVELS[*]}")],
    "requests_per_test": $REQUESTS_PER_TEST,
    "endpoints_tested": [$(printf '"%s",' "${!ENDPOINTS[@]}" | sed 's/,$//')],
    "warmup_requests": $WARMUP_REQUESTS
  },
  "dotnet": {
    "peak_throughput_rps": $DOTNET_PEAK,
    "endpoints": $DOTNET_RESULTS
  },
  "scala_play": {
    "peak_throughput_rps": $SCALA_PEAK,
    "endpoints": $SCALA_RESULTS
  },
  "comparison": {
    "peak_throughput_difference_rps": $(echo "$DOTNET_PEAK - $SCALA_PEAK" | bc),
    "dotnet_faster_by_percent": $(echo "scale=2; (($DOTNET_PEAK - $SCALA_PEAK) / $SCALA_PEAK) * 100" | bc)
  }
}
EOF

echo "Results saved to: $RESULTS_DIR/throughput_results.json"

# Generate a simple text summary
echo ""
echo "==================================="
echo "Summary"
echo "==================================="
echo ""
echo ".NET Peak Throughput: $DOTNET_PEAK req/sec"
echo "Scala Play Peak Throughput: $SCALA_PEAK req/sec"
echo ""

# Show best performing endpoint for each
DOTNET_BEST_ENDPOINT=$(echo "$DOTNET_RESULTS" | jq -r 'to_entries | max_by(.value | to_entries | max_by(.value.requests_per_second).value.requests_per_second) | .key')
DOTNET_BEST_RPS=$(echo "$DOTNET_RESULTS" | jq "[.[] | to_entries | max_by(.value.requests_per_second).value.requests_per_second] | max")

SCALA_BEST_ENDPOINT=$(echo "$SCALA_RESULTS" | jq -r 'to_entries | max_by(.value | to_entries | max_by(.value.requests_per_second).value.requests_per_second) | .key')
SCALA_BEST_RPS=$(echo "$SCALA_RESULTS" | jq "[.[] | to_entries | max_by(.value.requests_per_second).value.requests_per_second] | max")

echo ".NET Best: $DOTNET_BEST_ENDPOINT endpoint at $DOTNET_BEST_RPS req/sec"
echo "Scala Play Best: $SCALA_BEST_ENDPOINT endpoint at $SCALA_BEST_RPS req/sec"
echo ""
echo "==================================="
echo "Throughput Benchmark Complete"
echo "==================================="
