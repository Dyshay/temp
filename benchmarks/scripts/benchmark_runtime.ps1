# Benchmark runtime performance and RAM usage for .NET and Scala Play
# Requires: curl (built-in), Apache Bench (ab) or wrk, jq
# Output: JSON file with performance metrics

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ResultsDir = Join-Path $ProjectRoot "benchmarks\results"

# Create results directory
New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

Write-Host "==================================="
Write-Host "Runtime Performance Benchmark"
Write-Host "==================================="

# Configuration
$WARMUP_REQUESTS = 100
$BENCH_REQUESTS = 1000
$CONCURRENCY = 10
$WARMUP_TIME = 5

# Function to wait for service to be ready
function Wait-ForService {
    param(
        [string]$Url
    )

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

# Function to get process memory (Working Set in KB)
function Get-ProcessMemory {
    param(
        [int]$ProcessId
    )

    if ($ProcessId -eq 0) {
        return 0
    }

    try {
        $process = Get-Process -Id $ProcessId -ErrorAction Stop
        $memoryKB = [math]::Round($process.WorkingSet64 / 1KB)
        return $memoryKB
    }
    catch {
        return 0
    }
}

# Function to benchmark endpoint using Apache Bench
function Benchmark-Endpoint {
    param(
        [string]$Url,
        [string]$Name
    )

    Write-Host "    Testing: $Name"

    # Check if ab is available
    $abAvailable = Get-Command ab -ErrorAction SilentlyContinue

    if ($abAvailable) {
        # Use Apache Bench
        $abOutput = ab -n $BENCH_REQUESTS -c $CONCURRENCY -q $Url 2>&1 | Out-String

        # Extract metrics
        $rps = [regex]::Match($abOutput, 'Requests per second:\s+([\d.]+)').Groups[1].Value
        $meanTime = [regex]::Match($abOutput, 'Time per request:\s+([\d.]+)').Groups[1].Value
        $failed = [regex]::Match($abOutput, 'Failed requests:\s+(\d+)').Groups[1].Value

        if (-not $rps) { $rps = 0 }
        if (-not $meanTime) { $meanTime = 0 }
        if (-not $failed) { $failed = 0 }

        $rps = [double]$rps
        $meanTime = [double]$meanTime
        $failed = [int]$failed
    }
    else {
        # Fallback: Use PowerShell to measure performance
        Write-Host "      (Using PowerShell fallback - install Apache Bench for better results)"

        $startTime = Get-Date
        $failedCount = 0

        for ($i = 0; $i -lt $BENCH_REQUESTS; $i++) {
            try {
                Invoke-WebRequest -Uri $Url -TimeoutSec 5 -UseBasicParsing | Out-Null
            }
            catch {
                $failedCount++
            }
        }

        $endTime = Get-Date
        $duration = ($endTime - $startTime).TotalSeconds
        $rps = [math]::Round($BENCH_REQUESTS / $duration, 2)
        $meanTime = [math]::Round(($duration / $BENCH_REQUESTS) * 1000, 2)
        $failed = $failedCount
    }

    Write-Host "      RPS: $rps, Mean time: ${meanTime}ms, Failed: $failed"

    return @{
        rps = $rps
        mean_time_ms = $meanTime
        failed_requests = $failed
    }
}

# Function to run benchmarks for a service
function Benchmark-Service {
    param(
        [string]$Name,
        [string]$BaseUrl,
        [int]$ProcessId
    )

    Write-Host ""
    Write-Host "Benchmarking $Name..."

    # Warmup
    Write-Host "  Warming up ($WARMUP_REQUESTS requests)..."
    try {
        if (Get-Command ab -ErrorAction SilentlyContinue) {
            ab -n $WARMUP_REQUESTS -c $CONCURRENCY -q "$BaseUrl/api/hello" 2>&1 | Out-Null
        }
        else {
            for ($i = 0; $i -lt $WARMUP_REQUESTS; $i++) {
                Invoke-WebRequest -Uri "$BaseUrl/api/hello" -UseBasicParsing | Out-Null
            }
        }
    }
    catch {
        Write-Host "  Warning: Warmup encountered errors"
    }
    Start-Sleep -Seconds $WARMUP_TIME

    # Measure memory after warmup
    $memIdle = Get-ProcessMemory -ProcessId $ProcessId
    $memIdleMB = [math]::Round($memIdle / 1024, 2)
    Write-Host "  Memory (idle): $memIdle KB ($memIdleMB MB)"

    # Benchmark endpoints
    $helloResult = Benchmark-Endpoint -Url "$BaseUrl/api/hello" -Name "GET /api/hello"
    $echoResult = Benchmark-Endpoint -Url "$BaseUrl/api/echo/test" -Name "GET /api/echo"
    $computeResult = Benchmark-Endpoint -Url "$BaseUrl/api/compute/10000" -Name "GET /api/compute"

    # Measure memory under load
    $memLoad = Get-ProcessMemory -ProcessId $ProcessId
    $memLoadMB = [math]::Round($memLoad / 1024, 2)
    Write-Host "  Memory (under load): $memLoad KB ($memLoadMB MB)"

    return @{
        memory_idle_kb = $memIdle
        memory_idle_mb = $memIdleMB
        memory_load_kb = $memLoad
        memory_load_mb = $memLoadMB
        endpoints = @{
            hello = $helloResult
            echo = $echoResult
            compute = $computeResult
        }
    }
}

# Check if ab is installed
$abInstalled = Get-Command ab -ErrorAction SilentlyContinue
if (-not $abInstalled) {
    Write-Host ""
    Write-Host "WARNING: Apache Bench (ab) is not installed."
    Write-Host "For best results, install it from: https://www.apachelounge.com/download/"
    Write-Host "Or install wrk: choco install wrk"
    Write-Host ""
    Write-Host "Falling back to PowerShell HTTP client (slower and less accurate)..."
    Write-Host ""
    Start-Sleep -Seconds 3
}

# Start .NET application
Write-Host ""
Write-Host "Starting .NET application..."
Set-Location "$ProjectRoot\dotnet-api"

if (-not (Test-Path ".\publish")) {
    Write-Host "  Building first..."
    dotnet publish -c Release -o .\publish *> $null
}

$dotnetProcess = Start-Process -FilePath "dotnet" -ArgumentList ".\publish\DotNetApi.dll" -PassThru -WindowStyle Hidden
$DOTNET_PID = $dotnetProcess.Id
Write-Host "  Started with PID: $DOTNET_PID"

$serviceReady = Wait-ForService -Url "http://127.0.0.1:5000/api/hello"
if (-not $serviceReady) {
    Stop-Process -Id $DOTNET_PID -Force -ErrorAction SilentlyContinue
    throw "Failed to start .NET service"
}

# Benchmark .NET
$dotnetResults = Benchmark-Service -Name ".NET" -BaseUrl "http://127.0.0.1:5000" -ProcessId $DOTNET_PID

# Stop .NET
Write-Host ""
Write-Host "Stopping .NET application..."
Stop-Process -Id $DOTNET_PID -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Start Scala Play application
Write-Host ""
Write-Host "Starting Scala Play application..."
Set-Location "$ProjectRoot\scala-play-api"

if (-not (Test-Path ".\target\universal\stage")) {
    Write-Host "  Building first..."
    cmd /c sbt stage *> $null
}

# Use PowerShell script instead of .bat to avoid Windows "line too long" error
$startScript = Join-Path $ProjectRoot "scala-play-api\start-play.ps1"

if (-not (Test-Path $startScript)) {
    throw "Scala Play PowerShell start script not found at: $startScript"
}

# Start the application in background using PowerShell
$scalaProcess = Start-Process -FilePath "powershell.exe" `
    -ArgumentList "-ExecutionPolicy", "Bypass", "-File", "`"$startScript`"" `
    -PassThru -WindowStyle Hidden

# Wait a bit for Java process to start
Start-Sleep -Seconds 3

# Find the actual Java process (child of PowerShell)
$javaProcess = Get-Process -Name "java" -ErrorAction SilentlyContinue |
    Where-Object { $_.StartTime -gt (Get-Date).AddSeconds(-10) } |
    Select-Object -First 1

if ($javaProcess) {
    $SCALA_PID = $javaProcess.Id
    Write-Host "  Started with PID: $SCALA_PID (Java process)"
} else {
    $SCALA_PID = $scalaProcess.Id
    Write-Host "  Started with PID: $SCALA_PID (PowerShell wrapper)"
}

$serviceReady = Wait-ForService -Url "http://127.0.0.1:9000/api/hello"
if (-not $serviceReady) {
    Stop-Process -Id $scalaProcess.Id -Force -ErrorAction SilentlyContinue
    if ($javaProcess) {
        Stop-Process -Id $javaProcess.Id -Force -ErrorAction SilentlyContinue
    }
    throw "Failed to start Scala Play service"
}

# Benchmark Scala Play
$scalaResults = Benchmark-Service -Name "Scala Play" -BaseUrl "http://127.0.0.1:9000" -ProcessId $SCALA_PID

# Stop Scala Play
Write-Host ""
Write-Host "Stopping Scala Play application..."
# Stop both PowerShell wrapper and Java process
Stop-Process -Id $scalaProcess.Id -Force -ErrorAction SilentlyContinue
if ($javaProcess) {
    Stop-Process -Id $javaProcess.Id -Force -ErrorAction SilentlyContinue
}
# Also kill any remaining java processes on port 9000
Get-Process -Name "java" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Generate JSON report
Write-Host ""
Write-Host "Generating report..."

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$dotnetHelloRps = $dotnetResults.endpoints.hello.rps
$scalaHelloRps = $scalaResults.endpoints.hello.rps
$dotnetMemIdle = $dotnetResults.memory_idle_mb
$scalaMemIdle = $scalaResults.memory_idle_mb

$rpsDiff = [math]::Round($dotnetHelloRps - $scalaHelloRps, 2)
$rpsPercentDiff = if ($scalaHelloRps -ne 0) {
    [math]::Round((($dotnetHelloRps - $scalaHelloRps) / $scalaHelloRps) * 100, 2)
} else {
    0
}
$memDiff = [math]::Round($scalaMemIdle - $dotnetMemIdle, 2)
$memPercentDiff = if ($scalaMemIdle -ne 0) {
    [math]::Round((($scalaMemIdle - $dotnetMemIdle) / $scalaMemIdle) * 100, 2)
} else {
    0
}

$report = @{
    timestamp = $timestamp
    test_config = @{
        warmup_requests = $WARMUP_REQUESTS
        benchmark_requests = $BENCH_REQUESTS
        concurrency = $CONCURRENCY
    }
    dotnet = $dotnetResults
    scala_play = $scalaResults
    comparison = @{
        hello_endpoint_rps_difference = $rpsDiff
        hello_endpoint_dotnet_faster_percent = $rpsPercentDiff
        memory_idle_difference_mb = $memDiff
        memory_dotnet_lighter_percent = $memPercentDiff
    }
}

$report | ConvertTo-Json -Depth 10 | Set-Content "$ResultsDir\runtime_results.json"

Write-Host "Results saved to: $ResultsDir\runtime_results.json"
Write-Host ""
Write-Host "==================================="
Write-Host "Runtime Benchmark Complete"
Write-Host "==================================="
