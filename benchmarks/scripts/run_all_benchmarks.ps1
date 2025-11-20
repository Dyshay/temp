# Master script to run all benchmarks
# This script runs compilation, package size, startup, and runtime benchmarks

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ResultsDir = Join-Path (Split-Path -Parent (Split-Path -Parent $ScriptDir)) "benchmarks\results"

Write-Host "==========================================="
Write-Host "  .NET vs Scala Play - Full Benchmark Suite"
Write-Host "==========================================="
Write-Host ""
Write-Host "This will run the following benchmarks:"
Write-Host "  1. Compilation time"
Write-Host "  2. Package size"
Write-Host "  3. Startup time (cold, warm, hot)"
Write-Host "  4. Runtime performance & RAM usage"
Write-Host "  5. JSON serialization (if endpoint available)"
Write-Host "  6. LINQ & Collections (if endpoint available)"
Write-Host "  7. Throughput at different concurrency levels"
Write-Host "  8. Load testing (progressive load)"
Write-Host ""
Write-Host "Estimated time: 45-60 minutes"
Write-Host ""
Write-Host "Press Enter to continue or Ctrl+C to cancel..."
Read-Host

# Create results directory
New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

# Clear old results
Write-Host ""
Write-Host "Clearing old results..."
Remove-Item -Path "$ResultsDir\*.json" -Force -ErrorAction SilentlyContinue

# Run compilation benchmark
Write-Host ""
Write-Host "==========================================="
Write-Host "Step 1/8: Compilation Benchmark"
Write-Host "==========================================="
& "$ScriptDir\benchmark_compilation.ps1"

# Run package size benchmark
Write-Host ""
Write-Host "==========================================="
Write-Host "Step 2/8: Package Size Benchmark"
Write-Host "==========================================="
& "$ScriptDir\benchmark_package_size.ps1"

# Run startup time benchmark
Write-Host ""
Write-Host "==========================================="
Write-Host "Step 3/8: Startup Time Benchmark"
Write-Host "==========================================="
Write-Host ""
Write-Host "NOTE: This benchmark requires Administrator privileges to clean up ports."
Write-Host "If it fails, please run this entire script as Administrator."
Write-Host ""
& "$ScriptDir\benchmark_startup.ps1"

# Run runtime benchmark
Write-Host ""
Write-Host "==========================================="
Write-Host "Step 4/8: Runtime Performance Benchmark"
Write-Host "==========================================="
& "$ScriptDir\benchmark_runtime.ps1"

# # Run JSON benchmark
# Write-Host ""
# Write-Host "==========================================="
# Write-Host "Step 5/8: JSON Serialization Benchmark"
# Write-Host "==========================================="
# & "$ScriptDir\benchmark_json.ps1"
#
# # Run LINQ & Collections benchmark
# Write-Host ""
# Write-Host "==========================================="
# Write-Host "Step 6/8: LINQ & Collections Benchmark"
# Write-Host "==========================================="
# & "$ScriptDir\benchmark_linq_collections.ps1"

# Run throughput benchmark
Write-Host ""
Write-Host "==========================================="
Write-Host "Step 7/8: Throughput Benchmark"
Write-Host "==========================================="
& "$ScriptDir\benchmark_throughput.ps1"

# Run load test benchmark
Write-Host ""
Write-Host "==========================================="
Write-Host "Step 8/8: Load Testing Benchmark"
Write-Host "==========================================="
& "$ScriptDir\benchmark_load_test.ps1"

# Generate comprehensive report (if generate_report.ps1 exists)
if (Test-Path "$ScriptDir\generate_report.ps1") {
    Write-Host ""
    Write-Host "==========================================="
    Write-Host "Generating Comprehensive Report"
    Write-Host "==========================================="
    & "$ScriptDir\generate_report.ps1"
}

Write-Host ""
Write-Host "==========================================="
Write-Host "All Benchmarks Complete!"
Write-Host "==========================================="
Write-Host ""
Write-Host "Results available in: $ResultsDir\"
Write-Host "  - compilation_results.json"
Write-Host "  - package_size_results.json"
Write-Host "  - startup_results.json"
Write-Host "  - runtime_results.json"
Write-Host "  - json_results.json"
Write-Host "  - linq_collections_results.json"
Write-Host "  - throughput_results.json"
Write-Host "  - load_test_results.json"
Write-Host ""

if (Test-Path "$ResultsDir\comprehensive_report.md") {
    Write-Host "View comprehensive report:"
    Write-Host "  Get-Content $ResultsDir\comprehensive_report.md"
    Write-Host "  OR: notepad $ResultsDir\comprehensive_report.md"
}

Write-Host ""
