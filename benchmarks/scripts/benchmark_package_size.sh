#!/bin/bash

# Benchmark package size for .NET and Scala Play
# Output: JSON file with package sizes

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/benchmarks/results"

mkdir -p "$RESULTS_DIR"

echo "==================================="
echo "Package Size Benchmark"
echo "==================================="

# Function to get directory size in bytes
get_size_bytes() {
    du -sb "$1" | cut -f1
}

# Function to format bytes to human readable
format_bytes() {
    local bytes=$1
    if [ $bytes -lt 1024 ]; then
        echo "${bytes}B"
    elif [ $bytes -lt 1048576 ]; then
        echo "$(echo "scale=2; $bytes / 1024" | bc)KB"
    else
        echo "$(echo "scale=2; $bytes / 1048576" | bc)MB"
    fi
}

# Measure .NET package size
echo ""
echo "Measuring .NET package size..."
cd "$PROJECT_ROOT/dotnet-api"

if [ ! -d "./publish" ]; then
    echo "  Building .NET application..."
    dotnet publish -c Release -o ./publish > /dev/null 2>&1
fi

DOTNET_SIZE_BYTES=$(get_size_bytes "./publish")
DOTNET_SIZE_HUMAN=$(format_bytes $DOTNET_SIZE_BYTES)
echo "  - Published size: $DOTNET_SIZE_HUMAN ($DOTNET_SIZE_BYTES bytes)"

# Count files
DOTNET_FILE_COUNT=$(find ./publish -type f | wc -l)
echo "  - File count: $DOTNET_FILE_COUNT"

# DLL size
DOTNET_DLL_SIZE=$(get_size_bytes "./publish/DotNetApi.dll" 2>/dev/null || echo "0")
DOTNET_DLL_SIZE_HUMAN=$(format_bytes $DOTNET_DLL_SIZE)
echo "  - Main DLL size: $DOTNET_DLL_SIZE_HUMAN ($DOTNET_DLL_SIZE bytes)"

# Measure Scala Play package size
echo ""
echo "Measuring Scala Play package size..."
cd "$PROJECT_ROOT/scala-play-api"

if [ ! -d "./target/universal/stage" ]; then
    echo "  Building Scala Play application..."
    sbt stage > /dev/null 2>&1
fi

SCALA_SIZE_BYTES=$(get_size_bytes "./target/universal/stage")
SCALA_SIZE_HUMAN=$(format_bytes $SCALA_SIZE_BYTES)
echo "  - Staged size: $SCALA_SIZE_HUMAN ($SCALA_SIZE_BYTES bytes)"

# Count files
SCALA_FILE_COUNT=$(find ./target/universal/stage -type f | wc -l)
echo "  - File count: $SCALA_FILE_COUNT"

# JAR sizes
SCALA_LIB_SIZE=$(get_size_bytes "./target/universal/stage/lib" 2>/dev/null || echo "0")
SCALA_LIB_SIZE_HUMAN=$(format_bytes $SCALA_LIB_SIZE)
echo "  - Lib directory size: $SCALA_LIB_SIZE_HUMAN ($SCALA_LIB_SIZE bytes)"

# Generate JSON report
echo ""
echo "Generating report..."
cat > "$RESULTS_DIR/package_size_results.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "dotnet": {
    "total_size_bytes": $DOTNET_SIZE_BYTES,
    "total_size_mb": $(echo "scale=2; $DOTNET_SIZE_BYTES / 1048576" | bc),
    "total_size_human": "$DOTNET_SIZE_HUMAN",
    "file_count": $DOTNET_FILE_COUNT,
    "main_dll_size_bytes": $DOTNET_DLL_SIZE,
    "main_dll_size_human": "$DOTNET_DLL_SIZE_HUMAN"
  },
  "scala_play": {
    "total_size_bytes": $SCALA_SIZE_BYTES,
    "total_size_mb": $(echo "scale=2; $SCALA_SIZE_BYTES / 1048576" | bc),
    "total_size_human": "$SCALA_SIZE_HUMAN",
    "file_count": $SCALA_FILE_COUNT,
    "lib_size_bytes": $SCALA_LIB_SIZE,
    "lib_size_human": "$SCALA_LIB_SIZE_HUMAN"
  },
  "comparison": {
    "size_difference_bytes": $(echo "$SCALA_SIZE_BYTES - $DOTNET_SIZE_BYTES" | bc),
    "size_difference_mb": $(echo "scale=2; ($SCALA_SIZE_BYTES - $DOTNET_SIZE_BYTES) / 1048576" | bc),
    "dotnet_smaller_by_percent": $(echo "scale=2; (($SCALA_SIZE_BYTES - $DOTNET_SIZE_BYTES) / $SCALA_SIZE_BYTES) * 100" | bc)
  }
}
EOF

echo "Results saved to: $RESULTS_DIR/package_size_results.json"
echo ""
echo "==================================="
echo "Package Size Benchmark Complete"
echo "==================================="
