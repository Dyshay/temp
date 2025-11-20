# Benchmark throughput (requests/sec) at different concurrency levels
# Output: JSON file with throughput metrics
# Requires: Apache Bench (ab) or fallback to PowerShell

$ErrorActionPreference = "Continue"

$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Split-Path -Parent (Split-Path -Parent $ScriptDir)
$ResultsDir = Join-Path $ProjectRoot "benchmarks\results"

# Import common functions
. "$ScriptDir\common_functions.ps1"

New-Item -ItemType Directory -Force -Path $ResultsDir | Out-Null

Write-Host "==================================="
Write-Host "Throughput Benchmark"
Write-Host "==================================="

# Configuration
$CONCURRENCY_LEVELS = @(1, 10, 50, 100, 200)
$REQUESTS_PER_TEST = 1000
$WARMUP_REQUESTS = 100

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

# Function to benchmark with Apache Bench
function Benchmark-WithAB {
    param(
        [string]$Url,
        [int]$Requests,
        [int]$Concurrency
    )

    try {
        $abOutput = ab -n $Requests -c $Concurrency -q $Url 2>&1 | Out-String

        $rps = [regex]::Match($abOutput, 'Requests per second:\s+([\d.]+)').Groups[1].Value
        $meanTime = [regex]::Match($abOutput, 'Time per request:\s+([\d.]+)').Groups[1].Value
        $failed = [regex]::Match($abOutput, 'Failed requests:\s+(\d+)').Groups[1].Value

        if (-not $rps) { $rps = 0 }
        if (-not $meanTime) { $meanTime = 0 }
        if (-not $failed) { $failed = 0 }

        return @{
            rps = [double]$rps
            mean_time_ms = [double]$meanTime
            failed_requests = [int]$failed
        }
    }
    catch {
        return $null
    }
}

# Function to benchmark with PowerShell (fallback)
function Benchmark-WithPowerShell {
    param(
        [string]$Url,
        [int]$Requests,
        [int]$Concurrency
    )

    Write-Host "    Using PowerShell fallback (slower, less accurate)..." -ForegroundColor Yellow

    $startTime = Get-Date
    $failedCount = 0
    $completed = 0

    # Simple sequential requests (PowerShell doesn't handle concurrency well for this)
    for ($i = 0; $i -lt $Requests; $i++) {
        try {
            Invoke-WebRequest -Uri $Url -TimeoutSec 5 -UseBasicParsing | Out-Null
            $completed++
        }
        catch {
            $failedCount++
        }

        # Progress indicator
        if (($i % 100) -eq 0) {
            Write-Host "      Progress: $i / $Requests" -NoNewline -ForegroundColor DarkGray
            Write-Host "`r" -NoNewline
        }
    }

    $endTime = Get-Date
    $duration = ($endTime - $startTime).TotalSeconds
    $rps = [math]::Round($completed / $duration, 2)
    $meanTime = [math]::Round(($duration / $completed) * 1000, 2)

    return @{
        rps = $rps
        mean_time_ms = $meanTime
        failed_requests = $failedCount
    }
}

# Check if ab is available
$abAvailable = Get-Command ab -ErrorAction SilentlyContinue

if (-not $abAvailable) {
    Write-Host ""
    Write-Host "WARNING: Apache Bench (ab) not found" -ForegroundColor Yellow
    Write-Host "Falling back to PowerShell (slower and less accurate)" -ForegroundColor Yellow
    Write-Host "For better results, install Apache Bench or wrk" -ForegroundColor Yellow
    Write-Host ""
}

# Ensure applications are built
Write-Host ""
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

# Start .NET application
Write-Host ""
Write-Host "Starting .NET application..."
Set-Location "$ProjectRoot\dotnet-api"
$dotnetProcess = Start-Process -FilePath "dotnet" -ArgumentList ".\publish\DotNetApi.dll" -PassThru -WindowStyle Hidden
$DOTNET_PID = $dotnetProcess.Id
Write-Host "  Started with PID: $DOTNET_PID"

$serviceReady = Wait-ForService -Url "http://127.0.0.1:5000/api/hello"
if (-not $serviceReady) {
    Stop-Process -Id $DOTNET_PID -Force -ErrorAction SilentlyContinue
    throw "Failed to start .NET service"
}

# Warmup
Write-Host "  Warming up..."
if ($abAvailable) {
    ab -n $WARMUP_REQUESTS -c 10 -q "http://127.0.0.1:5000/api/hello" *> $null
}
Start-Sleep -Seconds 2

# Benchmark .NET at different concurrency levels
Write-Host ""
Write-Host "Benchmarking .NET throughput..."
$dotnetResults = @{}

foreach ($concurrency in $CONCURRENCY_LEVELS) {
    Write-Host "  Testing with concurrency: $concurrency"

    if ($abAvailable) {
        $result = Benchmark-WithAB -Url "http://127.0.0.1:5000/api/hello" -Requests $REQUESTS_PER_TEST -Concurrency $concurrency
    }
    else {
        $result = Benchmark-WithPowerShell -Url "http://127.0.0.1:5000/api/hello" -Requests ([math]::Min($REQUESTS_PER_TEST, 200)) -Concurrency $concurrency
    }

    if ($result) {
        Write-Host "    RPS: $($result.rps), Mean: $($result.mean_time_ms)ms, Failed: $($result.failed_requests)"
        $dotnetResults[$concurrency.ToString()] = $result
    }
}

# Stop .NET
Write-Host ""
Write-Host "Stopping .NET application..."
Stop-Process -Id $DOTNET_PID -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 2

# Start Scala Play application
Write-Host ""
Write-Host "Starting Scala Play application..."

$scalaInfo = Start-ScalaPlayApp -ProjectRoot $ProjectRoot

$serviceReady = Wait-ForService -Url "http://127.0.0.1:9000/api/hello"
if (-not $serviceReady) {
    Stop-ScalaPlayApp -ProcessInfo $scalaInfo
    throw "Failed to start Scala Play service"
}

# Warmup
Write-Host "  Warming up..."
if ($abAvailable) {
    ab -n $WARMUP_REQUESTS -c 10 -q "http://127.0.0.1:9000/api/hello" *> $null
}
Start-Sleep -Seconds 2

# Benchmark Scala Play at different concurrency levels
Write-Host ""
Write-Host "Benchmarking Scala Play throughput..."
$scalaResults = @{}

foreach ($concurrency in $CONCURRENCY_LEVELS) {
    Write-Host "  Testing with concurrency: $concurrency"

    if ($abAvailable) {
        $result = Benchmark-WithAB -Url "http://127.0.0.1:9000/api/hello" -Requests $REQUESTS_PER_TEST -Concurrency $concurrency
    }
    else {
        $result = Benchmark-WithPowerShell -Url "http://127.0.0.1:9000/api/hello" -Requests ([math]::Min($REQUESTS_PER_TEST, 200)) -Concurrency $concurrency
    }

    if ($result) {
        Write-Host "    RPS: $($result.rps), Mean: $($result.mean_time_ms)ms, Failed: $($result.failed_requests)"
        $scalaResults[$concurrency.ToString()] = $result
    }
}

# Stop Scala Play
Write-Host ""
Write-Host "Stopping Scala Play application..."
Stop-ScalaPlayApp -ProcessInfo $scalaInfo

# Generate report
Write-Host ""
Write-Host "Generating report..."

$timestamp = (Get-Date).ToUniversalTime().ToString("yyyy-MM-ddTHH:mm:ssZ")

$report = @{
    timestamp = $timestamp
    concurrency_levels = $CONCURRENCY_LEVELS
    requests_per_test = $REQUESTS_PER_TEST
    tool_used = if ($abAvailable) { "Apache Bench" } else { "PowerShell" }
    dotnet = $dotnetResults
    scala_play = $scalaResults
}

$report | ConvertTo-Json -Depth 10 | Set-Content "$ResultsDir\throughput_results.json"

Write-Host "Results saved to: $ResultsDir\throughput_results.json"
Write-Host ""
Write-Host "==================================="
Write-Host "Throughput Benchmark Complete"
Write-Host "==================================="
