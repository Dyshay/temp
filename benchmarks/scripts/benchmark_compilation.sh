#!/bin/bash

# Benchmark compilation time for .NET and Scala Play
# Output: JSON file with compilation times

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/benchmarks/results"

mkdir -p "$RESULTS_DIR"

echo "==================================="
echo "Compilation Time Benchmark"
echo "==================================="

# Function to measure time
measure_time() {
    local start=$(date +%s.%N)
    "$@"
    local end=$(date +%s.%N)
    echo $(echo "$end - $start" | bc)
}

# Clean previous builds
echo ""
echo "Cleaning previous builds..."
cd "$PROJECT_ROOT/dotnet-api"
dotnet clean > /dev/null 2>&1 || true
rm -rf bin obj

cd "$PROJECT_ROOT/scala-play-api"
rm -rf target project/target project/project

# Benchmark .NET compilation
echo ""
echo "Benchmarking .NET compilation..."
cd "$PROJECT_ROOT/dotnet-api"

# Restore dependencies (first time)
echo "  - Restoring dependencies..."
DOTNET_RESTORE_TIME=$(measure_time dotnet restore)
echo "    Restore time: ${DOTNET_RESTORE_TIME}s"

# Build (Release mode)
echo "  - Building (Release)..."
DOTNET_BUILD_TIME=$(measure_time dotnet build -c Release --no-restore)
echo "    Build time: ${DOTNET_BUILD_TIME}s"

# Publish
echo "  - Publishing..."
DOTNET_PUBLISH_TIME=$(measure_time dotnet publish -c Release -o ./publish --no-build)
echo "    Publish time: ${DOTNET_PUBLISH_TIME}s"

DOTNET_TOTAL_TIME=$(echo "$DOTNET_RESTORE_TIME + $DOTNET_BUILD_TIME + $DOTNET_PUBLISH_TIME" | bc)
echo "  - Total time: ${DOTNET_TOTAL_TIME}s"

# Benchmark Scala Play compilation
echo ""
echo "Benchmarking Scala Play compilation..."
cd "$PROJECT_ROOT/scala-play-api"

# Update dependencies
echo "  - Updating dependencies..."
SCALA_UPDATE_TIME=$(measure_time sbt update)
echo "    Update time: ${SCALA_UPDATE_TIME}s"

# Compile
echo "  - Compiling..."
SCALA_COMPILE_TIME=$(measure_time sbt compile)
echo "    Compile time: ${SCALA_COMPILE_TIME}s"

# Stage (package)
echo "  - Staging..."
SCALA_STAGE_TIME=$(measure_time sbt stage)
echo "    Stage time: ${SCALA_STAGE_TIME}s"

SCALA_TOTAL_TIME=$(echo "$SCALA_UPDATE_TIME + $SCALA_COMPILE_TIME + $SCALA_STAGE_TIME" | bc)
echo "  - Total time: ${SCALA_TOTAL_TIME}s"

# Generate JSON report
echo ""
echo "Generating report..."
cat > "$RESULTS_DIR/compilation_results.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "dotnet": {
    "restore_time_seconds": $DOTNET_RESTORE_TIME,
    "build_time_seconds": $DOTNET_BUILD_TIME,
    "publish_time_seconds": $DOTNET_PUBLISH_TIME,
    "total_time_seconds": $DOTNET_TOTAL_TIME
  },
  "scala_play": {
    "update_time_seconds": $SCALA_UPDATE_TIME,
    "compile_time_seconds": $SCALA_COMPILE_TIME,
    "stage_time_seconds": $SCALA_STAGE_TIME,
    "total_time_seconds": $SCALA_TOTAL_TIME
  },
  "comparison": {
    "dotnet_faster_by_seconds": $(echo "$SCALA_TOTAL_TIME - $DOTNET_TOTAL_TIME" | bc),
    "dotnet_faster_by_percent": $(echo "scale=2; (($SCALA_TOTAL_TIME - $DOTNET_TOTAL_TIME) / $SCALA_TOTAL_TIME) * 100" | bc)
  }
}
EOF

echo "Results saved to: $RESULTS_DIR/compilation_results.json"
echo ""
echo "==================================="
echo "Compilation Benchmark Complete"
echo "==================================="
