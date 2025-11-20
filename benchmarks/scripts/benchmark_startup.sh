#!/bin/bash

# Benchmark startup times (cold, warm, hot) for .NET and Scala Play
# Output: JSON file with startup times

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/benchmarks/results"

mkdir -p "$RESULTS_DIR"

echo "==================================="
echo "Startup Time Benchmark"
echo "==================================="

# Function to measure startup time
measure_startup() {
    local url=$1
    local max_attempts=60
    local attempt=0
    local start=$(date +%s.%N)

    while [ $attempt -lt $max_attempts ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            local end=$(date +%s.%N)
            echo $(echo "$end - $start" | bc)
            return 0
        fi
        attempt=$((attempt + 1))
        sleep 0.5
    done
    echo "ERROR: Service did not start in time" >&2
    return 1
}

# Function to test .NET startup
test_dotnet_startup() {
    local type=$1
    echo "  Testing $type startup..."

    cd "$PROJECT_ROOT/dotnet-api"

    # Start the application in background
    dotnet ./publish/DotNetApi.dll > /dev/null 2>&1 &
    local pid=$!

    # Measure time to first successful response
    local startup_time=$(measure_startup "http://localhost:5000/api/hello")

    # Stop the application
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true

    # Small delay between tests
    sleep 2

    echo "    Startup time: ${startup_time}s"
    echo $startup_time
}

# Function to test Scala Play startup
test_scala_startup() {
    local type=$1
    echo "  Testing $type startup..."

    cd "$PROJECT_ROOT/scala-play-api"

    # Start the application in background
    ./target/universal/stage/bin/scala-play-api > /dev/null 2>&1 &
    local pid=$!

    # Measure time to first successful response
    local startup_time=$(measure_startup "http://localhost:9000/api/hello")

    # Stop the application
    kill $pid 2>/dev/null || true
    wait $pid 2>/dev/null || true

    # Small delay between tests
    sleep 2

    echo "    Startup time: ${startup_time}s"
    echo $startup_time
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

# Test .NET startup times
echo ""
echo "Testing .NET startup times..."

echo "  Cold start (first run after build):"
DOTNET_COLD=$(test_dotnet_startup "cold")

echo "  Warm start (second run):"
DOTNET_WARM=$(test_dotnet_startup "warm")

echo "  Hot start (third run):"
DOTNET_HOT=$(test_dotnet_startup "hot")

# Calculate average
DOTNET_AVG=$(echo "scale=3; ($DOTNET_COLD + $DOTNET_WARM + $DOTNET_HOT) / 3" | bc)
echo "  Average: ${DOTNET_AVG}s"

# Test Scala Play startup times
echo ""
echo "Testing Scala Play startup times..."

echo "  Cold start (first run after build):"
SCALA_COLD=$(test_scala_startup "cold")

echo "  Warm start (second run):"
SCALA_WARM=$(test_scala_startup "warm")

echo "  Hot start (third run):"
SCALA_HOT=$(test_scala_startup "hot")

# Calculate average
SCALA_AVG=$(echo "scale=3; ($SCALA_COLD + $SCALA_WARM + $SCALA_HOT) / 3" | bc)
echo "  Average: ${SCALA_AVG}s"

# Generate JSON report
echo ""
echo "Generating report..."
cat > "$RESULTS_DIR/startup_results.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "dotnet": {
    "cold_start_seconds": $DOTNET_COLD,
    "warm_start_seconds": $DOTNET_WARM,
    "hot_start_seconds": $DOTNET_HOT,
    "average_seconds": $DOTNET_AVG
  },
  "scala_play": {
    "cold_start_seconds": $SCALA_COLD,
    "warm_start_seconds": $SCALA_WARM,
    "hot_start_seconds": $SCALA_HOT,
    "average_seconds": $SCALA_AVG
  },
  "comparison": {
    "cold_start_difference_seconds": $(echo "$SCALA_COLD - $DOTNET_COLD" | bc),
    "warm_start_difference_seconds": $(echo "$SCALA_WARM - $DOTNET_WARM" | bc),
    "hot_start_difference_seconds": $(echo "$SCALA_HOT - $DOTNET_HOT" | bc),
    "average_difference_seconds": $(echo "$SCALA_AVG - $DOTNET_AVG" | bc),
    "dotnet_faster_by_percent": $(echo "scale=2; (($SCALA_AVG - $DOTNET_AVG) / $SCALA_AVG) * 100" | bc)
  }
}
EOF

echo "Results saved to: $RESULTS_DIR/startup_results.json"
echo ""
echo "==================================="
echo "Startup Benchmark Complete"
echo "==================================="
