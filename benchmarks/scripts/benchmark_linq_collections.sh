#!/bin/bash

# Benchmark LINQ vs Collections for .NET and equivalent functional operations for Scala Play
# Output: JSON file with LINQ and collection performance metrics

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
RESULTS_DIR="$PROJECT_ROOT/benchmarks/results"

mkdir -p "$RESULTS_DIR"

echo "==================================="
echo "LINQ & Collections Benchmark"
echo "==================================="

# Configuration
DATA_SIZES=(1000 10000 50000 100000)
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
    curl -s "http://127.0.0.1:5000/api/linq-benchmark/1000" > /dev/null
    curl -s "http://127.0.0.1:5000/api/collection-benchmark/1000" > /dev/null
done
sleep 2

# Benchmark .NET LINQ
echo ""
echo "Benchmarking .NET LINQ operations..."
DOTNET_LINQ_RESULTS="{"
for size in "${DATA_SIZES[@]}"; do
    echo "  Testing with $size elements..."

    # Run multiple times and average
    total_linq=0
    total_loop=0
    total_complex=0
    runs=5

    for run in $(seq 1 $runs); do
        result=$(curl -s "http://127.0.0.1:5000/api/linq-benchmark/$size")
        linq_time=$(echo "$result" | jq -r '.linqTimeMs')
        loop_time=$(echo "$result" | jq -r '.forLoopTimeMs')
        complex_time=$(echo "$result" | jq -r '.complexLinqTimeMs')

        total_linq=$(echo "$total_linq + $linq_time" | bc)
        total_loop=$(echo "$total_loop + $loop_time" | bc)
        total_complex=$(echo "$total_complex + $complex_time" | bc)
    done

    avg_linq=$(echo "scale=3; $total_linq / $runs" | bc)
    avg_loop=$(echo "scale=3; $total_loop / $runs" | bc)
    avg_complex=$(echo "scale=3; $total_complex / $runs" | bc)
    diff_percent=$(echo "scale=2; (($avg_linq - $avg_loop) / $avg_loop) * 100" | bc)

    echo "    LINQ: ${avg_linq}ms, For Loop: ${avg_loop}ms, Complex LINQ: ${avg_complex}ms, Diff: ${diff_percent}%"

    if [ "$size" != "${DATA_SIZES[0]}" ]; then
        DOTNET_LINQ_RESULTS+=","
    fi
    DOTNET_LINQ_RESULTS+="\"$size\":{\"linqTimeMs\":$avg_linq,\"forLoopTimeMs\":$avg_loop,\"complexLinqTimeMs\":$avg_complex,\"linqSlowerByPercent\":$diff_percent}"
done
DOTNET_LINQ_RESULTS+="}"

# Benchmark .NET Collections
echo ""
echo "Benchmarking .NET collection operations..."
DOTNET_COLL_RESULTS="{"
for size in "${DATA_SIZES[@]}"; do
    echo "  Testing with $size elements..."

    # Run multiple times and average
    total_list_add=0
    total_list_search=0
    total_array_add=0
    total_array_search=0
    total_hashset_add=0
    total_hashset_search=0
    runs=5

    for run in $(seq 1 $runs); do
        result=$(curl -s "http://127.0.0.1:5000/api/collection-benchmark/$size")

        list_add=$(echo "$result" | jq -r '.list.addTimeMs')
        list_search=$(echo "$result" | jq -r '.list.searchTimeMs')
        array_add=$(echo "$result" | jq -r '.array.addTimeMs')
        array_search=$(echo "$result" | jq -r '.array.searchTimeMs')
        hashset_add=$(echo "$result" | jq -r '.hashSet.addTimeMs')
        hashset_search=$(echo "$result" | jq -r '.hashSet.searchTimeMs')

        total_list_add=$(echo "$total_list_add + $list_add" | bc)
        total_list_search=$(echo "$total_list_search + $list_search" | bc)
        total_array_add=$(echo "$total_array_add + $array_add" | bc)
        total_array_search=$(echo "$total_array_search + $array_search" | bc)
        total_hashset_add=$(echo "$total_hashset_add + $hashset_add" | bc)
        total_hashset_search=$(echo "$total_hashset_search + $hashset_search" | bc)
    done

    avg_list_add=$(echo "scale=3; $total_list_add / $runs" | bc)
    avg_list_search=$(echo "scale=3; $total_list_search / $runs" | bc)
    avg_array_add=$(echo "scale=3; $total_array_add / $runs" | bc)
    avg_array_search=$(echo "scale=3; $total_array_search / $runs" | bc)
    avg_hashset_add=$(echo "scale=3; $total_hashset_add / $runs" | bc)
    avg_hashset_search=$(echo "scale=3; $total_hashset_search / $runs" | bc)

    echo "    List: ${avg_list_add}ms/${avg_list_search}ms, Array: ${avg_array_add}ms/${avg_array_search}ms, HashSet: ${avg_hashset_add}ms/${avg_hashset_search}ms"

    if [ "$size" != "${DATA_SIZES[0]}" ]; then
        DOTNET_COLL_RESULTS+=","
    fi
    DOTNET_COLL_RESULTS+="\"$size\":{\"list\":{\"addTimeMs\":$avg_list_add,\"searchTimeMs\":$avg_list_search},\"array\":{\"addTimeMs\":$avg_array_add,\"searchTimeMs\":$avg_array_search},\"hashSet\":{\"addTimeMs\":$avg_hashset_add,\"searchTimeMs\":$avg_hashset_search}}"
done
DOTNET_COLL_RESULTS+="}"

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
    curl -s "http://127.0.0.1:9000/api/linq-benchmark/1000" > /dev/null
    curl -s "http://127.0.0.1:9000/api/collection-benchmark/1000" > /dev/null
done
sleep 2

# Benchmark Scala Play functional operations
echo ""
echo "Benchmarking Scala functional operations..."
SCALA_FUNC_RESULTS="{"
for size in "${DATA_SIZES[@]}"; do
    echo "  Testing with $size elements..."

    # Run multiple times and average
    total_func=0
    total_loop=0
    total_complex=0
    runs=5

    for run in $(seq 1 $runs); do
        result=$(curl -s "http://127.0.0.1:9000/api/linq-benchmark/$size")
        func_time=$(echo "$result" | jq -r '.functionalTimeMs')
        loop_time=$(echo "$result" | jq -r '.forLoopTimeMs')
        complex_time=$(echo "$result" | jq -r '.complexFunctionalTimeMs')

        total_func=$(echo "$total_func + $func_time" | bc)
        total_loop=$(echo "$total_loop + $loop_time" | bc)
        total_complex=$(echo "$total_complex + $complex_time" | bc)
    done

    avg_func=$(echo "scale=3; $total_func / $runs" | bc)
    avg_loop=$(echo "scale=3; $total_loop / $runs" | bc)
    avg_complex=$(echo "scale=3; $total_complex / $runs" | bc)
    diff_percent=$(echo "scale=2; (($avg_func - $avg_loop) / $avg_loop) * 100" | bc)

    echo "    Functional: ${avg_func}ms, For Loop: ${avg_loop}ms, Complex: ${avg_complex}ms, Diff: ${diff_percent}%"

    if [ "$size" != "${DATA_SIZES[0]}" ]; then
        SCALA_FUNC_RESULTS+=","
    fi
    SCALA_FUNC_RESULTS+="\"$size\":{\"functionalTimeMs\":$avg_func,\"forLoopTimeMs\":$avg_loop,\"complexFunctionalTimeMs\":$avg_complex,\"functionalSlowerByPercent\":$diff_percent}"
done
SCALA_FUNC_RESULTS+="}"

# Benchmark Scala Play Collections
echo ""
echo "Benchmarking Scala collection operations..."
SCALA_COLL_RESULTS="{"
for size in "${DATA_SIZES[@]}"; do
    echo "  Testing with $size elements..."

    # Run multiple times and average
    total_list_add=0
    total_list_search=0
    total_array_add=0
    total_array_search=0
    total_set_add=0
    total_set_search=0
    runs=5

    for run in $(seq 1 $runs); do
        result=$(curl -s "http://127.0.0.1:9000/api/collection-benchmark/$size")

        list_add=$(echo "$result" | jq -r '.list.addTimeMs')
        list_search=$(echo "$result" | jq -r '.list.searchTimeMs')
        array_add=$(echo "$result" | jq -r '.array.addTimeMs')
        array_search=$(echo "$result" | jq -r '.array.searchTimeMs')
        set_add=$(echo "$result" | jq -r '.set.addTimeMs')
        set_search=$(echo "$result" | jq -r '.set.searchTimeMs')

        total_list_add=$(echo "$total_list_add + $list_add" | bc)
        total_list_search=$(echo "$total_list_search + $list_search" | bc)
        total_array_add=$(echo "$total_array_add + $array_add" | bc)
        total_array_search=$(echo "$total_array_search + $array_search" | bc)
        total_set_add=$(echo "$total_set_add + $set_add" | bc)
        total_set_search=$(echo "$total_set_search + $set_search" | bc)
    done

    avg_list_add=$(echo "scale=3; $total_list_add / $runs" | bc)
    avg_list_search=$(echo "scale=3; $total_list_search / $runs" | bc)
    avg_array_add=$(echo "scale=3; $total_array_add / $runs" | bc)
    avg_array_search=$(echo "scale=3; $total_array_search / $runs" | bc)
    avg_set_add=$(echo "scale=3; $total_set_add / $runs" | bc)
    avg_set_search=$(echo "scale=3; $total_set_search / $runs" | bc)

    echo "    List: ${avg_list_add}ms/${avg_list_search}ms, Array: ${avg_array_add}ms/${avg_array_search}ms, Set: ${avg_set_add}ms/${avg_set_search}ms"

    if [ "$size" != "${DATA_SIZES[0]}" ]; then
        SCALA_COLL_RESULTS+=","
    fi
    SCALA_COLL_RESULTS+="\"$size\":{\"list\":{\"addTimeMs\":$avg_list_add,\"searchTimeMs\":$avg_list_search},\"array\":{\"addTimeMs\":$avg_array_add,\"searchTimeMs\":$avg_array_search},\"set\":{\"addTimeMs\":$avg_set_add,\"searchTimeMs\":$avg_set_search}}"
done
SCALA_COLL_RESULTS+="}"

# Stop Scala Play
echo ""
echo "Stopping Scala Play application..."
kill $SCALA_PID 2>/dev/null || true
wait $SCALA_PID 2>/dev/null || true

# Generate JSON report
echo ""
echo "Generating report..."
cat > "$RESULTS_DIR/linq_collections_results.json" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "data_sizes_tested": [$(IFS=,; echo "${DATA_SIZES[*]}")],
  "dotnet": {
    "linq_operations": $DOTNET_LINQ_RESULTS,
    "collections": $DOTNET_COLL_RESULTS
  },
  "scala_play": {
    "functional_operations": $SCALA_FUNC_RESULTS,
    "collections": $SCALA_COLL_RESULTS
  }
}
EOF

echo "Results saved to: $RESULTS_DIR/linq_collections_results.json"
echo ""
echo "==================================="
echo "LINQ & Collections Benchmark Complete"
echo "==================================="
