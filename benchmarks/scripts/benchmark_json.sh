#!/bin/bash

# Benchmark JSON serialization/deserialization for .NET and Scala Play
# Output: JSON file with serialization performance metrics

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/benchmarks/results"

mkdir -p "$RESULTS_DIR"

echo "==================================="
echo "JSON Serialization Benchmark"
echo "==================================="

# Configuration
OBJECT_COUNTS=(100 1000 5000 10000)
WARMUP_REQUESTS=10

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

# Function to benchmark JSON serialization
benchmark_json() {
    local url=$1
    local count=$2

    local response=$(curl -s -X POST "$url" \
        -H "Content-Type: application/json" \
        -d "{\"objectCount\":$count}")

    echo "$response"
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

# Warmup .NET
echo "  Warming up..."
for i in $(seq 1 $WARMUP_REQUESTS); do
    curl -s -X POST "http://127.0.0.1:5000/api/json-benchmark" \
        -H "Content-Type: application/json" \
        -d '{"objectCount":100}' > /dev/null
done
sleep 2

# Benchmark .NET
echo ""
echo "Benchmarking .NET JSON serialization..."
DOTNET_RESULTS="{"
for count in "${OBJECT_COUNTS[@]}"; do
    echo "  Testing with $count objects..."

    # Run multiple times and average
    total_serialize=0
    total_deserialize=0
    total_size=0
    runs=5

    for run in $(seq 1 $runs); do
        result=$(benchmark_json "http://127.0.0.1:5000/api/json-benchmark" $count)
        serialize=$(echo "$result" | jq -r '.serializationTimeMs')
        deserialize=$(echo "$result" | jq -r '.deserializationTimeMs')
        size=$(echo "$result" | jq -r '.jsonSizeBytes')

        total_serialize=$(echo "$total_serialize + $serialize" | bc)
        total_deserialize=$(echo "$total_deserialize + $deserialize" | bc)
        total_size=$(echo "$total_size + $size" | bc)
    done

    avg_serialize=$(echo "scale=3; $total_serialize / $runs" | bc)
    avg_deserialize=$(echo "scale=3; $total_deserialize / $runs" | bc)
    avg_size=$(echo "scale=0; $total_size / $runs" | bc)

    echo "    Avg Serialize: ${avg_serialize}ms, Avg Deserialize: ${avg_deserialize}ms, Size: ${avg_size} bytes"

    if [ "$count" != "${OBJECT_COUNTS[0]}" ]; then
        DOTNET_RESULTS+=","
    fi
    DOTNET_RESULTS+="\"$count\":{\"serializationTimeMs\":$avg_serialize,\"deserializationTimeMs\":$avg_deserialize,\"jsonSizeBytes\":$avg_size}"
done
DOTNET_RESULTS+="}"

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

# Warmup Scala Play
echo "  Warming up..."
for i in $(seq 1 $WARMUP_REQUESTS); do
    curl -s -X POST "http://127.0.0.1:9000/api/json-benchmark" \
        -H "Content-Type: application/json" \
        -d '{"objectCount":100}' > /dev/null
done
sleep 2

# Benchmark Scala Play
echo ""
echo "Benchmarking Scala Play JSON serialization..."
SCALA_RESULTS="{"
for count in "${OBJECT_COUNTS[@]}"; do
    echo "  Testing with $count objects..."

    # Run multiple times and average
    total_serialize=0
    total_deserialize=0
    total_size=0
    runs=5

    for run in $(seq 1 $runs); do
        result=$(benchmark_json "http://127.0.0.1:9000/api/json-benchmark" $count)
        serialize=$(echo "$result" | jq -r '.serializationTimeMs')
        deserialize=$(echo "$result" | jq -r '.deserializationTimeMs')
        size=$(echo "$result" | jq -r '.jsonSizeBytes')

        total_serialize=$(echo "$total_serialize + $serialize" | bc)
        total_deserialize=$(echo "$total_deserialize + $deserialize" | bc)
        total_size=$(echo "$total_size + $size" | bc)
    done

    avg_serialize=$(echo "scale=3; $total_serialize / $runs" | bc)
    avg_deserialize=$(echo "scale=3; $total_deserialize / $runs" | bc)
    avg_size=$(echo "scale=0; $total_size / $runs" | bc)

    echo "    Avg Serialize: ${avg_serialize}ms, Avg Deserialize: ${avg_deserialize}ms, Size: ${avg_size} bytes"

    if [ "$count" != "${OBJECT_COUNTS[0]}" ]; then
        SCALA_RESULTS+=","
    fi
    SCALA_RESULTS+="\"$count\":{\"serializationTimeMs\":$avg_serialize,\"deserializationTimeMs\":$avg_deserialize,\"jsonSizeBytes\":$avg_size}"
done
SCALA_RESULTS+="}"

# Stop Scala Play
echo ""
echo "Stopping Scala Play application..."
kill $SCALA_PID 2>/dev/null || true
wait $SCALA_PID 2>/dev/null || true

# Generate JSON report
echo ""
echo "Generating report..."
cat > "$RESULTS_DIR/json_results.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "object_counts_tested": [$(IFS=,; echo "${OBJECT_COUNTS[*]}")],
  "dotnet": $DOTNET_RESULTS,
  "scala_play": $SCALA_RESULTS
}
EOF

echo "Results saved to: $RESULTS_DIR/json_results.json"
echo ""
echo "==================================="
echo "JSON Benchmark Complete"
echo "==================================="
