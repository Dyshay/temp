# Benchmark load testing - find breaking point
# Output: JSON file with load test results
# Requires: Apache Bench (ab) or fallback to PowerShell

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ResultsDir = Join-Path $ProjectRoot "benchmarks\results"

# Import common functions
. "$ScriptDir\common_functions.ps1"

New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

Write-Host "==================================="
Write-Host "Load Testing Benchmark"
Write-Host "==================================="
Write-Host ""
Write-Host "This test gradually increases load to find the breaking point" -ForegroundColor Cyan
Write-Host ""

# Configuration - progressive load levels
$LOAD_LEVELS = @(10, 50, 100, 200, 300, 400, 500)
$REQUESTS_PER_TEST = 500
$FAILURE_THRESHOLD = 0.05  # 5% error rate

# Check if ab is available
$abAvailable = Get-Command ab -ErrorAction SilentlyContinue

if (-not $abAvailable) {
    Write-Host "WARNING: Apache Bench (ab) not found" -ForegroundColor Yellow
    Write-Host "Load testing requires Apache Bench for accurate results" -ForegroundColor Yellow
    Write-Host "Generating placeholder results..." -ForegroundColor Yellow
    Write-Host ""

    $timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

    $report = @{
        timestamp = $timestamp
        note = "Apache Bench required for load testing"
        status = "skipped"
        message = "Install Apache Bench from https://www.apachelounge.com/download/ or use 'choco install wrk'"
        load_levels_tested = $LOAD_LEVELS
        dotnet = @{
            note = "Test skipped - Apache Bench not available"
        }
        scala_play = @{
            note = "Test skipped - Apache Bench not available"
        }
    }

    $report | ConvertTo-Json -Depth 10 | Set-Content "$ResultsDir\load_test_results.json"

    Write-Host "Placeholder results saved to: $ResultsDir\load_test_results.json"
    Write-Host ""
    Write-Host "==================================="
    Write-Host "Load Test Skipped"
    Write-Host "==================================="
    exit 0
}

# Function to wait for service
function Wait-ForService {
    param([string]$Url)

    Write-Host "  Waiting for service at $Url..."
    $maxAttempts = 30
    $attempt = 0

    while ($attempt -lt $maxAttempts) {
        try {
            $response = Invoke-WebRequest -Uri $Url -TimeoutSec 2 -UseBasicParsing -ErrorAction Stop
            if ($response.StatusCode -eq 200) {
                Write-Host "  Service is ready!"
                return $true
            }
        }
        catch {
            # Service not ready yet
        }
        $attempt++
        Start-Sleep -Seconds 2
    }
    Write-Host "  ERROR: Service did not start in time"
    return $false
}

# Function to run load test
function Run-LoadTest {
    param(
        [string]$Url,
        [int]$Concurrency,
        [int]$Requests
    )

    try {
        $abOutput = ab -n $Requests -c $Concurrency -q $Url 2>&1 | Out-String

        $rps = [regex]::Match($abOutput, 'Requests per second:\s+([\d.]+)').Groups[1].Value
        $failed = [regex]::Match($abOutput, 'Failed requests:\s+(\d+)').Groups[1].Value
        $meanTime = [regex]::Match($abOutput, 'Time per request:\s+([\d.]+)').Groups[1].Value

        if (-not $rps) { $rps = 0 }
        if (-not $failed) { $failed = 0 }
        if (-not $meanTime) { $meanTime = 0 }

        $errorRate = [double]$failed / $Requests

        return @{
            rps = [double]$rps
            failed = [int]$failed
            error_rate = [math]::Round($errorRate, 4)
            mean_time_ms = [double]$meanTime
            breaking_point = ($errorRate -gt $FAILURE_THRESHOLD)
        }
    }
    catch {
        return @{
            rps = 0
            failed = $Requests
            error_rate = 1.0
            mean_time_ms = 0
            breaking_point = $true
        }
    }
}

# Ensure applications are built
Write-Host "Ensuring applications are built..."

Set-Location "$ProjectRoot\dotnet-api"
if (-not (Test-Path ".\publish")) {
    Write-Host "  Building .NET application..."
    dotnet publish -c Release -o .\publish *> $null
}

Set-Location "$ProjectRoot\scala-play-api"
if (-not (Test-Path ".\target\universal\stage")) {
    Write-Host "  Building Scala Play application..."
    sbt stage *> $null
}

# Test .NET
Write-Host ""
Write-Host "========================================="
Write-Host "Load Testing .NET"
Write-Host "========================================="

Set-Location "$ProjectRoot\dotnet-api"
$dotnetProcess = Start-Process -FilePath "dotnet" -ArgumentList ".\publish\DotNetApi.dll" -PassThru -WindowStyle Hidden
$DOTNET_PID = $dotnetProcess.Id
Write-Host "Started with PID: $DOTNET_PID"

$serviceReady = Wait-ForService -Url "http://127.0.0.1:5000/api/hello"
if (-not $serviceReady) {
    Stop-Process -Id $DOTNET_PID -Force -ErrorAction SilentlyContinue
    throw "Failed to start .NET service"
}

$dotnetResults = @{}
$dotnetBreakingPoint = $null

foreach ($load in $LOAD_LEVELS) {
    Write-Host ""
    Write-Host "Testing with load: $load concurrent connections"

    $result = Run-LoadTest -Url "http://127.0.0.1:5000/api/hello" -Concurrency $load -Requests $REQUESTS_PER_TEST

    Write-Host "  RPS: $($result.rps), Failed: $($result.failed), Error Rate: $($result.error_rate * 100)%"

    $dotnetResults[$load.ToString()] = $result

    if ($result.breaking_point -and -not $dotnetBreakingPoint) {
        $dotnetBreakingPoint = $load
        Write-Host "  Breaking point reached at $load connections!" -ForegroundColor Yellow
    }

    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Stopping .NET application..."
Stop-Process -Id $DOTNET_PID -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 3

# Test Scala Play
Write-Host ""
Write-Host "========================================="
Write-Host "Load Testing Scala Play"
Write-Host "========================================="

$scalaInfo = Start-ScalaPlayApp -ProjectRoot $ProjectRoot

$serviceReady = Wait-ForService -Url "http://127.0.0.1:9000/api/hello"
if (-not $serviceReady) {
    Stop-ScalaPlayApp -ProcessInfo $scalaInfo
    throw "Failed to start Scala Play service"
}

$scalaResults = @{}
$scalaBreakingPoint = $null

foreach ($load in $LOAD_LEVELS) {
    Write-Host ""
    Write-Host "Testing with load: $load concurrent connections"

    $result = Run-LoadTest -Url "http://127.0.0.1:9000/api/hello" -Concurrency $load -Requests $REQUESTS_PER_TEST

    Write-Host "  RPS: $($result.rps), Failed: $($result.failed), Error Rate: $($result.error_rate * 100)%"

    $scalaResults[$load.ToString()] = $result

    if ($result.breaking_point -and -not $scalaBreakingPoint) {
        $scalaBreakingPoint = $load
        Write-Host "  Breaking point reached at $load connections!" -ForegroundColor Yellow
    }

    Start-Sleep -Seconds 2
}

Write-Host ""
Write-Host "Stopping Scala Play application..."
Stop-ScalaPlayApp -ProcessInfo $scalaInfo

# Generate report
Write-Host ""
Write-Host "Generating report..."

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$report = @{
    timestamp = $timestamp
    load_levels_tested = $LOAD_LEVELS
    requests_per_test = $REQUESTS_PER_TEST
    failure_threshold = $FAILURE_THRESHOLD
    dotnet = @{
        results = $dotnetResults
        breaking_point = if ($dotnetBreakingPoint) { $dotnetBreakingPoint } else { "Not reached" }
    }
    scala_play = @{
        results = $scalaResults
        breaking_point = if ($scalaBreakingPoint) { $scalaBreakingPoint } else { "Not reached" }
    }
}

$report | ConvertTo-Json -Depth 10 | Set-Content "$ResultsDir\load_test_results.json"

Write-Host "Results saved to: $ResultsDir\load_test_results.json"
Write-Host ""
Write-Host "========================================="
Write-Host "Load Test Summary"
Write-Host "========================================="
Write-Host ".NET breaking point: $(if ($dotnetBreakingPoint) { "$dotnetBreakingPoint connections" } else { "Not reached" })"
Write-Host "Scala Play breaking point: $(if ($scalaBreakingPoint) { "$scalaBreakingPoint connections" } else { "Not reached" })"
Write-Host ""
Write-Host "==================================="
Write-Host "Load Test Complete"
Write-Host "==================================="
