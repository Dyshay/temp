#!/bin/bash

# Benchmark runtime performance and RAM usage for .NET and Scala Play
# Requires: curl, apache2-utils (ab), bc
# Output: JSON file with performance metrics

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/benchmarks/results"

mkdir -p "$RESULTS_DIR"

echo "==================================="
echo "Runtime Performance Benchmark"
echo "==================================="

# Configuration
WARMUP_REQUESTS=100
BENCH_REQUESTS=1000
CONCURRENCY=10
WARMUP_TIME=5

# Function to wait for service to be ready
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

# Function to get process memory (RSS in KB)
get_process_memory() {
    local pid=$1
    if [ -z "$pid" ] || ! ps -p $pid > /dev/null 2>&1; then
        echo "0"
        return
    fi
    ps -o rss= -p $pid | awk '{print $1}'
}

# Function to benchmark endpoint
benchmark_endpoint() {
    local url=$1
    local name=$2

    echo "    Testing: $name"

    # Run Apache Bench
    local ab_output=$(ab -n $BENCH_REQUESTS -c $CONCURRENCY -q "$url" 2>&1)

    # Extract metrics
    local rps=$(echo "$ab_output" | grep "Requests per second" | awk '{print $4}')
    local mean_time=$(echo "$ab_output" | grep "Time per request" | head -1 | awk '{print $4}')
    local failed=$(echo "$ab_output" | grep "Failed requests" | awk '{print $3}')

    echo "      RPS: $rps, Mean time: ${mean_time}ms, Failed: $failed"

    # Return as JSON
    echo "{\"rps\":$rps,\"mean_time_ms\":$mean_time,\"failed_requests\":$failed}"
}

# Function to run benchmarks for a service
benchmark_service() {
    local name=$1
    local base_url=$2
    local pid=$3

    echo ""
    echo "Benchmarking $name..."

    # Warmup
    echo "  Warming up ($WARMUP_REQUESTS requests)..."
    ab -n $WARMUP_REQUESTS -c $CONCURRENCY -q "$base_url/api/hello" > /dev/null 2>&1
    sleep $WARMUP_TIME

    # Measure memory after warmup
    local mem_idle=$(get_process_memory $pid)
    echo "  Memory (idle): ${mem_idle} KB"

    # Benchmark endpoints
    local hello_result=$(benchmark_endpoint "$base_url/api/hello" "GET /api/hello")
    local echo_result=$(benchmark_endpoint "$base_url/api/echo/test" "GET /api/echo")
    local compute_result=$(benchmark_endpoint "$base_url/api/compute/10000" "GET /api/compute")

    # Measure memory under load
    local mem_load=$(get_process_memory $pid)
    echo "  Memory (under load): ${mem_load} KB"

    # Return JSON
    cat <<EOF
{
  "memory_idle_kb": $mem_idle,
  "memory_idle_mb": $(echo "scale=2; $mem_idle / 1024" | bc),
  "memory_load_kb": $mem_load,
  "memory_load_mb": $(echo "scale=2; $mem_load / 1024" | bc),
  "endpoints": {
    "hello": $hello_result,
    "echo": $echo_result,
    "compute": $compute_result
  }
}
EOF
}

# Check if ab is installed
if ! command -v ab &> /dev/null; then
    echo "ERROR: Apache Bench (ab) is not installed."
    echo "Install with: apt-get install apache2-utils"
    exit 1
fi

# Start .NET application
echo ""
echo "Starting .NET application..."
cd "$PROJECT_ROOT/dotnet-api"

if [ ! -d "./publish" ]; then
    echo "  Building first..."
    dotnet publish -c Release -o ./publish > /dev/null 2>&1
fi

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

# Start Scala Play application
echo ""
echo "Starting Scala Play application..."
cd "$PROJECT_ROOT/scala-play-api"

if [ ! -d "./target/universal/stage" ]; then
    echo "  Building first..."
    sbt stage > /dev/null 2>&1
fi

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

# Generate JSON report
echo ""
echo "Generating report..."

# Extract values for comparison
DOTNET_HELLO_RPS=$(echo "$DOTNET_RESULTS" | jq -r '.endpoints.hello.rps')
SCALA_HELLO_RPS=$(echo "$SCALA_RESULTS" | jq -r '.endpoints.hello.rps')
DOTNET_MEM_IDLE=$(echo "$DOTNET_RESULTS" | jq -r '.memory_idle_mb')
SCALA_MEM_IDLE=$(echo "$SCALA_RESULTS" | jq -r '.memory_idle_mb')

cat > "$RESULTS_DIR/runtime_results.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "test_config": {
    "warmup_requests": $WARMUP_REQUESTS,
    "benchmark_requests": $BENCH_REQUESTS,
    "concurrency": $CONCURRENCY
  },
  "dotnet": $DOTNET_RESULTS,
  "scala_play": $SCALA_RESULTS,
  "comparison": {
    "hello_endpoint_rps_difference": $(echo "$DOTNET_HELLO_RPS - $SCALA_HELLO_RPS" | bc),
    "hello_endpoint_dotnet_faster_percent": $(echo "scale=2; (($DOTNET_HELLO_RPS - $SCALA_HELLO_RPS) / $SCALA_HELLO_RPS) * 100" | bc),
    "memory_idle_difference_mb": $(echo "$SCALA_MEM_IDLE - $DOTNET_MEM_IDLE" | bc),
    "memory_dotnet_lighter_percent": $(echo "scale=2; (($SCALA_MEM_IDLE - $DOTNET_MEM_IDLE) / $SCALA_MEM_IDLE) * 100" | bc)
  }
}
EOF

echo "Results saved to: $RESULTS_DIR/runtime_results.json"
echo ""
echo "==================================="
echo "Runtime Benchmark Complete"
echo "==================================="
