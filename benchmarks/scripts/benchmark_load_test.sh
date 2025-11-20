#!/bin/bash

# Progressive load test - gradually increase load to find breaking point
# This helps determine the maximum sustainable throughput

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/benchmarks/results"

mkdir -p "$RESULTS_DIR"

echo "==================================="
echo "Progressive Load Test"
echo "==================================="

# Configuration
DURATION_PER_STEP=10  # seconds
STEP_INCREMENT=50     # increase by this many concurrent connections each step
MAX_CONCURRENCY=500
WARMUP_TIME=5

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

# Function to run load test step
run_load_step() {
    local url=$1
    local concurrency=$2
    local duration=$3

    # Calculate total requests (roughly concurrency * requests_per_sec * duration)
    # We'll use a high number to ensure we run for the full duration
    local total_requests=$((concurrency * 1000 * duration))

    # Run ab with time limit
    local ab_output=$(timeout ${duration}s ab -n $total_requests -c $concurrency "$url" 2>&1 || true)

    # Extract metrics
    local rps=$(echo "$ab_output" | grep "Requests per second" | awk '{print $4}')
    local completed=$(echo "$ab_output" | grep "Complete requests" | awk '{print $3}')
    local failed=$(echo "$ab_output" | grep "Failed requests" | awk '{print $3}')
    local mean_time=$(echo "$ab_output" | grep "Time per request" | head -1 | awk '{print $4}')

    # Calculate error rate
    local error_rate=0
    if [ ! -z "$completed" ] && [ ! -z "$failed" ] && [ "$completed" != "0" ]; then
        error_rate=$(echo "scale=2; ($failed / $completed) * 100" | bc)
    fi

    echo "$rps|$completed|$failed|$error_rate|$mean_time"
}

# Function to run progressive load test
progressive_load_test() {
    local name=$1
    local base_url=$2

    echo ""
    echo "Running progressive load test for $name..."
    echo ""

    # Warmup
    echo "  Warming up..."
    ab -n 500 -c 10 -q "$base_url/api/hello" > /dev/null 2>&1
    sleep $WARMUP_TIME

    local results="["
    local concurrency=$STEP_INCREMENT
    local first=true

    echo "  Starting load test (${DURATION_PER_STEP}s per step)..."
    echo ""
    printf "  %-15s %-15s %-15s %-15s %-15s\n" "Concurrency" "RPS" "Completed" "Failed" "Error %"
    printf "  %s\n" "--------------------------------------------------------------------------------"

    while [ $concurrency -le $MAX_CONCURRENCY ]; do
        # Run test
        local result=$(run_load_step "$base_url/api/hello" $concurrency $DURATION_PER_STEP)

        # Parse result
        IFS='|' read -r rps completed failed error_rate mean_time <<< "$result"

        # Display
        printf "  %-15s %-15s %-15s %-15s %-15s\n" \
            "$concurrency" \
            "${rps:-0}" \
            "${completed:-0}" \
            "${failed:-0}" \
            "${error_rate:-0}%"

        # Add to JSON results
        if [ "$first" = false ]; then
            results+=","
        fi
        first=false

        results+=$(cat <<EOF
{
  "concurrency": $concurrency,
  "requests_per_second": ${rps:-0},
  "completed_requests": ${completed:-0},
  "failed_requests": ${failed:-0},
  "error_rate_percent": ${error_rate:-0},
  "mean_latency_ms": ${mean_time:-0}
}
EOF
)

        # Check if we're hitting too many errors (> 5%)
        if (( $(echo "$error_rate > 5" | bc -l) )); then
            echo ""
            echo "  WARNING: Error rate exceeding 5% at concurrency $concurrency"
            echo "  Stopping load test to prevent overload"
            break
        fi

        # Increment concurrency
        concurrency=$((concurrency + STEP_INCREMENT))

        # Small delay between steps
        sleep 2
    done

    results+="]"
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

# Test .NET
DOTNET_RESULTS=$(progressive_load_test ".NET" "http://127.0.0.1:5000")

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

# Test Scala Play
SCALA_RESULTS=$(progressive_load_test "Scala Play" "http://127.0.0.1:9000")

# Stop Scala Play
echo ""
echo "Stopping Scala Play application..."
kill $SCALA_PID 2>/dev/null || true
wait $SCALA_PID 2>/dev/null || true

# Generate JSON report
echo ""
echo "Generating report..."

# Find peak sustainable load (last entry before errors spiked)
DOTNET_PEAK_RPS=$(echo "$DOTNET_RESULTS" | jq '[.[] | select(.error_rate_percent < 1) | .requests_per_second] | max')
DOTNET_PEAK_CONCURRENCY=$(echo "$DOTNET_RESULTS" | jq -r ".[] | select(.requests_per_second == $DOTNET_PEAK_RPS) | .concurrency")

SCALA_PEAK_RPS=$(echo "$SCALA_RESULTS" | jq '[.[] | select(.error_rate_percent < 1) | .requests_per_second] | max')
SCALA_PEAK_CONCURRENCY=$(echo "$SCALA_RESULTS" | jq -r ".[] | select(.requests_per_second == $SCALA_PEAK_RPS) | .concurrency")

cat > "$RESULTS_DIR/load_test_results.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_configuration": {
    "duration_per_step_seconds": $DURATION_PER_STEP,
    "step_increment": $STEP_INCREMENT,
    "max_concurrency_tested": $MAX_CONCURRENCY
  },
  "dotnet": {
    "peak_sustainable_rps": $DOTNET_PEAK_RPS,
    "peak_sustainable_concurrency": $DOTNET_PEAK_CONCURRENCY,
    "load_test_results": $DOTNET_RESULTS
  },
  "scala_play": {
    "peak_sustainable_rps": $SCALA_PEAK_RPS,
    "peak_sustainable_concurrency": $SCALA_PEAK_CONCURRENCY,
    "load_test_results": $SCALA_RESULTS
  },
  "comparison": {
    "rps_difference": $(echo "$DOTNET_PEAK_RPS - $SCALA_PEAK_RPS" | bc),
    "dotnet_faster_by_percent": $(echo "scale=2; (($DOTNET_PEAK_RPS - $SCALA_PEAK_RPS) / $SCALA_PEAK_RPS) * 100" | bc)
  }
}
EOF

echo "Results saved to: $RESULTS_DIR/load_test_results.json"

# Summary
echo ""
echo "==================================="
echo "Summary"
echo "==================================="
echo ""
echo ".NET:"
echo "  Peak Sustainable Throughput: $DOTNET_PEAK_RPS req/sec"
echo "  At Concurrency: $DOTNET_PEAK_CONCURRENCY"
echo ""
echo "Scala Play:"
echo "  Peak Sustainable Throughput: $SCALA_PEAK_RPS req/sec"
echo "  At Concurrency: $SCALA_PEAK_CONCURRENCY"
echo ""
echo "==================================="
echo "Load Test Complete"
echo "==================================="
